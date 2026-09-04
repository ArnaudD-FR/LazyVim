-- Live preview for reStructuredText files via sphinx-autobuild.
--
-- Runs the full Sphinx build rooted at the nearest conf.py (found by walking
-- up from this file), not just the current file, so toctree entries and
-- cross-references resolve the same way they would in the real docs build.
-- Prefers `pixi run` or `uv run`, whichever manifest (pixi.toml/pyproject.toml)
-- sits nearest, so project-specific extensions/themes resolve the same way
-- they would in CI, rather than whatever `sphinx-autobuild` happens to be
-- first on PATH.

local function find_upward(name, from)
  local found = vim.fs.find(name, { upward = true, path = from })[1]
  return found and vim.fs.dirname(found) or nil
end

-- Whichever manifest sits nearest to `from` wins: a pixi.toml, or a
-- pyproject.toml, either plain (uv) or carrying pixi's own `[tool.pixi.*]`
-- tables (pixi also supports living inside a PEP 621 pyproject.toml).
local RUNNERS = {
  pixi = { bin = "pixi", file = "pixi.toml", sections = { "pypi-dependencies", "dependencies" } },
  ["pixi-pyproject"] = {
    bin = "pixi",
    file = "pyproject.toml",
    sections = { "tool.pixi.pypi-dependencies", "tool.pixi.dependencies" },
  },
  uv = { bin = "uv", file = "pyproject.toml", sections = { "tool.uv.sources" } },
}

local function find_env_manifest(from)
  local pixi_dir = find_upward("pixi.toml", from)
  local pyproject_dir = find_upward("pyproject.toml", from)
  if pixi_dir and (not pyproject_dir or #pixi_dir >= #pyproject_dir) then
    return pixi_dir, "pixi"
  end
  if pyproject_dir then
    local ok, lines = pcall(vim.fn.readfile, pyproject_dir .. "/pyproject.toml")
    if ok then
      for _, line in ipairs(lines) do
        if line:match("^%s*%[tool%.pixi[%.%]]") then
          return pyproject_dir, "pixi-pyproject"
        end
      end
    end
    return pyproject_dir, "uv"
  end
  return nil, nil
end

-- sphinx-autobuild only watches its sourcedir by default, so a dependency
-- pinned to a local path (e.g. a theme developed alongside these docs, not
-- yet published) needs to be watched explicitly for its edits to trigger a
-- rebuild too.
local function local_path_deps(dir, file, sections)
  local dirs = {}
  local ok, lines = pcall(vim.fn.readfile, dir .. "/" .. file)
  if not ok then
    return dirs
  end
  local in_section = false
  for _, line in ipairs(lines) do
    local section = line:match("^%s*%[(.-)%]%s*$")
    if section then
      in_section = vim.tbl_contains(sections, section)
    elseif in_section then
      local path = line:match('path%s*=%s*"([^"]+)"')
      if path then
        local abs = vim.fs.normalize(dir .. "/" .. path)
        if vim.fn.isdirectory(abs) == 1 then
          table.insert(dirs, abs)
        end
      end
    end
  end
  return dirs
end

-- Tracks, per Sphinx project (keyed by `src`), the running preview's base URL
-- and the page last asked for. A plain global rather than a file-local: this
-- ftplugin is re-sourced for every rst buffer, so a local would reset on each
-- buffer switch and forget that the server is already running.
_G.__rst_preview = _G.__rst_preview or {}

local function current_page(src)
  return vim.fs.normalize(vim.fn.expand("%:p")):sub(#vim.fs.normalize(src) + 2):gsub("%.rst$", ".html")
end

-- Points a running preview's browser tab at `page_url`, remembering it on
-- `state` so a later call (another buffer switch, or a second <leader>cp
-- press) can tell whether the page actually changed.
local function navigate(state, page_url)
  state.page_url = page_url
  if state.base_url then
    vim.ui.open(state.base_url .. "/" .. page_url)
  end
end

local function scan_for_base_url(lines)
  for _, line in ipairs(lines) do
    local base_url = line:match("Serving on (http://%S+)")
    if base_url then
      return base_url
    end
  end
  return nil
end

-- sphinx-autobuild only tells us its address once it's actually listening
-- (picked because --port 0 means the port isn't known ahead of time): watch
-- its log for "Serving on http://host:port" and hand it to `on_found`.
local function watch_for_base_url(term, on_found)
  vim.api.nvim_buf_attach(term.buf, false, {
    on_lines = function()
      if not vim.api.nvim_buf_is_valid(term.buf) then
        return true
      end
      local base_url = scan_for_base_url(vim.api.nvim_buf_get_lines(term.buf, -20, -1, false))
      if base_url then
        vim.schedule(function()
          on_found(base_url)
        end)
        return true
      end
    end,
  })
end

-- Same idea as `watch_for_base_url`, but for a hidden `jobstart` job (the
-- sync sidecar has no terminal buffer to attach to) instead of a Snacks
-- terminal buffer. `on_stdout` chunks don't necessarily land on line
-- boundaries, so the first element of each `data` continues the previous
-- chunk's possibly-incomplete last line, and its own last element is held
-- back as `pending` rather than scanned, since it may be incomplete too.
local function watch_job_for_base_url(on_found)
  local pending = ""
  local found = false
  return function(_, data)
    if found or not data or #data == 0 then
      return
    end
    local lines = { pending .. data[1] }
    for i = 2, #data do
      lines[#lines + 1] = data[i]
    end
    pending = table.remove(lines)
    local base_url = scan_for_base_url(lines)
    if base_url then
      found = true
      on_found(base_url)
    end
  end
end

-- Resolves how to run the scroll-sync sidecar in the same Python
-- environment as sphinx-autobuild, so its dependencies (starlette, uvicorn,
-- docutils: all already required by sphinx-autobuild itself) are guaranteed
-- importable. Mirrors `preview()`'s own runner resolution when a
-- pixi/uv manifest was found; otherwise resolves the interpreter from
-- sphinx-autobuild's own shebang, since whatever installed it has the same
-- dependencies available. Returns nil if neither is possible.
local SIDECAR_SCRIPT = vim.fs.joinpath(vim.fn.stdpath("config"), "scripts", "rst_sync_sidecar.py")

local function resolve_sidecar_cmd(runner, manifest_dir, src)
  if runner and vim.fn.executable(runner.bin) == 1 then
    return { runner.bin, "run", "python", SIDECAR_SCRIPT }, manifest_dir
  end

  local sab = vim.fn.exepath("sphinx-autobuild")
  if sab == "" then
    return nil
  end
  local ok, lines = pcall(vim.fn.readfile, sab, "", 1)
  local shebang = ok and lines[1] and lines[1]:match("^#!%s*(.+)$")
  if not shebang then
    return nil
  end
  local cmd = vim.split(vim.trim(shebang), "%s+")
  table.insert(cmd, SIDECAR_SCRIPT)
  return cmd, src
end

-- Fire-and-forget: tell the running sidecar where the cursor is so it can
-- push a scroll position to the browser. Always records the position, even
-- before a preview/sidecar exists, so the first thing the browser sees once
-- the sidecar comes up is already the right spot rather than the top of the
-- page. Shells out to curl rather than hand-rolling HTTP over `vim.uv`: the
-- response is never read, calls are already debounced to a handful a
-- second, and curl gets request framing/timeouts right for free.
local function post_cursor(state, file, line)
  state.last_file = file
  state.last_line = line
  if not state.base_url then
    return
  end
  local body = vim.json.encode({ file = file, line = line, page = state.page_url })
  vim.system({
    "curl",
    "-fsS",
    "--max-time",
    "1",
    "-o",
    "/dev/null",
    "-X",
    "POST",
    state.base_url .. "/__rst_sync/cursor",
    "-H",
    "Content-Type: application/json",
    "--data-binary",
    body,
  })
end

-- Launches the scroll-sync sidecar (a small reverse proxy in front of
-- sphinx-autobuild that injects a script for cursor-follow scrolling) and,
-- once it reports its own address, points the browser at it instead of at
-- sphinx-autobuild directly (`navigate`/`sync_preview` don't need to know
-- the difference). Falls back to previewing against sphinx-autobuild
-- directly, with one notification, if the sidecar can't be resolved,
-- fails to start, or never comes up (e.g. this project's env predates the
-- Starlette-based sphinx-autobuild the sidecar relies on): scroll-sync is
-- strictly additive, never a regression risk to the working preview.
local function launch_sidecar(state, backend_url, cmd_prefix, cwd)
  local function fall_back(reason)
    if reason then
      vim.notify("Sphinx preview: " .. reason .. "; previewing without scroll-sync", vim.log.levels.WARN)
    end
    state.base_url = backend_url
    navigate(state, state.page_url)
  end

  if not cmd_prefix then
    fall_back("couldn't resolve a Python interpreter for the scroll-sync sidecar")
    return
  end

  local ready = false
  local on_stdout = watch_job_for_base_url(function(sidecar_url)
    ready = true
    state.base_url = sidecar_url
    navigate(state, state.page_url)
    if state.last_line then
      -- Replays whatever cursor position was already recorded (possibly
      -- before the sidecar finished starting), so the first paint lands on
      -- the right spot instead of waiting for the next cursor move.
      post_cursor(state, state.last_file, state.last_line)
    end
  end)

  local cmd = vim.deepcopy(cmd_prefix)
  vim.list_extend(cmd, { "--backend-url", backend_url })
  local job = vim.fn.jobstart(cmd, {
    cwd = cwd,
    on_stdout = on_stdout,
    on_exit = function()
      if not ready then
        fall_back("scroll-sync sidecar unavailable in this project's env")
      end
    end,
  })

  if job <= 0 then
    fall_back("failed to start the scroll-sync sidecar")
    return
  end
  state.sidecar_job = job

  vim.defer_fn(function()
    if not ready and state.sidecar_job == job then
      vim.fn.jobstop(job)
    end
  end, 5000)
end

local function preview()
  local src = find_upward("conf.py", vim.fn.expand("%:p:h"))
  if not src then
    vim.notify("No conf.py found above this file; not a Sphinx project", vim.log.levels.WARN)
    return
  end

  local out = src .. "/_build/html"
  local ignore = { "--ignore", "*/_build/*", "--ignore", "*/.venv/*", "--ignore", "*/.pixi/*" }
  -- A fixed port would collide the moment a second Neovim instance (this
  -- project or another) starts its own preview; --port 0 asks sphinx-autobuild
  -- to pick a free one instead, so every instance gets its own server.
  local base = { src, out, "--port", "0" }
  local page_url = current_page(src)
  local cmd, cwd

  local manifest_dir, kind = find_env_manifest(src)
  local runner = kind and RUNNERS[kind]
  if runner and vim.fn.executable(runner.bin) == 1 then
    cmd = vim.list_extend(vim.list_extend({ runner.bin, "run", "sphinx-autobuild" }, base), ignore)
    for _, dir in ipairs(local_path_deps(manifest_dir, runner.file, runner.sections)) do
      vim.list_extend(cmd, { "--watch", dir })
    end
    cwd = manifest_dir
  elseif vim.fn.executable("sphinx-autobuild") == 1 then
    cmd = vim.list_extend(vim.list_extend({ "sphinx-autobuild" }, base), ignore)
    cwd = src
  else
    vim.notify("sphinx-autobuild not found (pip/uv/pixi add sphinx-autobuild to the docs project)", vim.log.levels.ERROR)
    return
  end

  -- A bottom split, not the default centered float, so the rst buffer stays
  -- visible and editable while sphinx-autobuild keeps running alongside it.
  local opts = { cwd = cwd, win = { position = "bottom", height = 0.25 } }
  local term, created = Snacks.terminal.get(cmd, opts)
  local state = _G.__rst_preview[src]
  if created then
    state = {
      page_url = page_url,
      last_file = vim.fn.expand("%:p"),
      last_line = vim.fn.line("."),
    }
    _G.__rst_preview[src] = state
    watch_for_base_url(term, function(backend_url)
      state.real_backend_url = backend_url
      if term:buf_valid() then
        term:hide()
      end
      local sidecar_cmd, sidecar_cwd = resolve_sidecar_cmd(runner, manifest_dir, src)
      launch_sidecar(state, backend_url, sidecar_cmd, sidecar_cwd)
    end)
  elseif state and state.base_url and state.page_url == page_url then
    -- Same page pressed again while already open: this press stops the
    -- server (kills the job), rather than just hiding its log split.
    _G.__rst_preview[src] = nil
    if state.sidecar_job then
      vim.fn.jobstop(state.sidecar_job)
    end
    term:close()
    vim.notify("Sphinx preview stopped", vim.log.levels.INFO)
  else
    -- Server already running (or still starting up) for this project, but
    -- for a different page: jump the existing preview to this one instead
    -- of touching the server.
    state = state or {}
    _G.__rst_preview[src] = state
    navigate(state, page_url)
  end
end

-- Keeps an already-running preview pointed at whichever rst buffer is
-- current, so switching buffers updates the browser without a <leader>cp
-- press. Does nothing if no preview is running for this buffer's project.
local function sync_preview()
  local src = find_upward("conf.py", vim.fn.expand("%:p:h"))
  local state = src and _G.__rst_preview[src]
  if not state then
    return
  end
  local page_url = current_page(src)
  if state.page_url ~= page_url then
    navigate(state, page_url)
  end
end

-- Pushes the cursor's line to the running preview's sidecar (if any) so it
-- can scroll the browser to follow it. Debounced: CursorMoved fires on
-- every cursor step, but sub-100ms pushes would only spawn curl processes
-- faster than the browser could usefully react to them.
local scroll_sync_cursor = Snacks.util.debounce(function()
  local src = find_upward("conf.py", vim.fn.expand("%:p:h"))
  local state = src and _G.__rst_preview[src]
  if not state then
    return
  end
  post_cursor(state, vim.fn.expand("%:p"), vim.fn.line("."))
end, { ms = 120 })

vim.keymap.set("n", "<leader>cp", preview, { buffer = true, desc = "Sphinx Preview" })
vim.api.nvim_create_autocmd("BufEnter", {
  group = vim.api.nvim_create_augroup("rst_preview_sync", { clear = false }),
  buffer = 0,
  callback = sync_preview,
})
vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
  group = vim.api.nvim_create_augroup("rst_preview_scroll_sync", { clear = false }),
  buffer = 0,
  callback = scroll_sync_cursor,
})
sync_preview()

vim.b.undo_ftplugin = "silent! unmap <buffer> <leader>cp"
  .. " | au! rst_preview_sync BufEnter <buffer>"
  .. " | au! rst_preview_scroll_sync CursorMoved <buffer>"
  .. " | au! rst_preview_scroll_sync CursorMovedI <buffer>"
