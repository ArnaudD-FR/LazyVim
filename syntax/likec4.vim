" Vim syntax file
" Language:     LikeC4 (architecture-as-code DSL) -- https://likec4.dev
" Extensions:   *.c4, *.likec4, *.like-c4
" Maintainer:   local config
"
" Keyword set derived from the authoritative Langium grammar
" (packages/language-server/src/like-c4.langium), not the TextMate grammar,
" which omits `summary`, `rank`, `variant`, `sequence` and the dynamic-view
" control keywords.
"
" Design notes:
"  * Enum *values* (shapes, colors, sizes, arrow heads, ...) are `contained`
"    `syn match` items reached only through `nextgroup` from the property that
"    introduces them. That is deliberate: their vocabularies overlap (`none`
"    is a color, an arrow head and a border style; `solid dashed dotted` are
"    both line and border styles), and overlapping `syn keyword` groups would
"    silently clobber one another -- in Vim the last definition of a word
"    wins. Contained matches selected per-nextgroup have no such conflict.
"  * For the same reason every non-contained keyword below appears in exactly
"    one group.
"  * `person` therefore highlights as a shape in `shape person` and as a kind
"    name in `element person`, which is the point.

if exists('b:current_syntax')
  finish
endif

let s:cpo_save = &cpoptions
set cpoptions&vim

scriptencoding utf-8
syn case match

" Embed Markdown inside triple-quoted blocks. `syn include` sets
" b:current_syntax as a side effect, so clear it on both sides.
unlet! b:current_syntax
syn include @likec4Markdown syntax/markdown.vim
unlet! b:current_syntax

" ---------------------------------------------------------------------------
" Comments
" ---------------------------------------------------------------------------
syn keyword likec4Todo contained TODO FIXME XXX HACK NOTE
syn region  likec4BlockComment start=+/\*+ end=+\*/+ keepend contains=likec4Todo,@Spell
syn match   likec4LineComment  +//.*+ contains=likec4Todo,@Spell

" ---------------------------------------------------------------------------
" Strings
" ---------------------------------------------------------------------------
" Escape sequences, ported from packages/vscode/likec4.tmLanguage.json
syn match likec4Escape /\\\%(x\x\{2}\|u\x\{4}\|u{\x\+}\|[0-2][0-7]\{0,2}\|3[0-6][0-7]\?\|37[0-7]\?\|[4-7][0-7]\?\|.\|$\)/ contained

syn region likec4SString start=+'+ skip=+\\.+ end=+'+ keepend contains=likec4Escape
syn region likec4DString start=+"+ skip=+\\.+ end=+"+ keepend contains=likec4Escape

" Triple-quoted Markdown blocks. Defined AFTER the single-character strings so
" that they win at the same start position (last definition takes priority).
" LikeC4 only opens such a block when the delimiter ends the line.
syn region likec4TripleSString matchgroup=likec4StringDelim
      \ start=+'''\s*$+ end=+'''+ keepend contains=@likec4Markdown,@Spell
syn region likec4TripleDString matchgroup=likec4StringDelim
      \ start=+"""\s*$+ end=+"""+ keepend contains=@likec4Markdown,@Spell

" ---------------------------------------------------------------------------
" Enum values (contained; reached via nextgroup only -- see design notes)
" ---------------------------------------------------------------------------
syn match likec4EnumShape /\<\%(rectangle\|component\|person\|browser\|mobile\|cylinder\|storage\|queue\|bucket\|document\)\>/ contained
syn match likec4EnumColor /\<\%(amber\|blue\|gray\|green\|indigo\|muted\|primary\|secondary\|red\|sky\|slate\|none\)\>/ contained
syn match likec4EnumLineStyle /\<\%(solid\|dashed\|dotted\|none\)\>/ contained
syn match likec4EnumArrow /\<\%(none\|normal\|onormal\|diamond\|odiamond\|dot\|odot\|crow\|vee\)\>/ contained
syn match likec4EnumSize /\<\%(xsmall\|xlarge\|small\|medium\|large\|xs\|sm\|md\|lg\|xl\)\>/ contained
syn match likec4EnumIconPos /\<\%(left\|right\|top\|bottom\)\>/ contained
syn match likec4EnumDirection /\<\%(TopBottom\|LeftRight\|BottomTop\|RightLeft\)\>/ contained
syn match likec4EnumRank /\<\%(same\|source\|sink\|min\|max\)\>/ contained
syn match likec4EnumVariant /\<\%(diagram\|sequence\)\>/ contained

" Kind / identifier introduced by a declaration keyword.
syn match likec4KindName /[A-Za-z_][A-Za-z0-9_]*\%(-[A-Za-z0-9_]\+\)*/ contained

" ---------------------------------------------------------------------------
" Top-level blocks
" ---------------------------------------------------------------------------
syn keyword likec4Block specification model views deployment global likec4lib import

" ---------------------------------------------------------------------------
" Declarations -- `element foo`, `tag bar`, `relationship async`
" Defined exactly once, and NOT repeated in any other keyword group.
" ---------------------------------------------------------------------------
syn keyword likec4Decl element tag relationship deploymentNode
      \ nextgroup=likec4KindName skipwhite

syn keyword likec4Structural view extend extends of from group node instance
      \ instanceOf open icons predicate predicateGroup dynamicPredicateGroup
      \ styleGroup dynamic sequence
      \ nextgroup=likec4KindName skipwhite

" ---------------------------------------------------------------------------
" Properties
" ---------------------------------------------------------------------------
syn keyword likec4Property title description summary technology notation link
      \ navigateTo metadata opacity style order kind

syn keyword likec4PropShape    shape        nextgroup=likec4EnumShape skipwhite
syn keyword likec4PropColor    color iconColor
      \ nextgroup=likec4EnumColor,likec4HexColor,likec4Function,likec4KindName skipwhite
syn keyword likec4PropLine     line border  nextgroup=likec4EnumLineStyle skipwhite
syn keyword likec4PropArrow    head tail    nextgroup=likec4EnumArrow skipwhite
syn keyword likec4PropSize     size padding textSize iconSize
      \ nextgroup=likec4EnumSize skipwhite
syn keyword likec4PropIconPos  iconPosition nextgroup=likec4EnumIconPos skipwhite
syn keyword likec4PropLayout   autoLayout   nextgroup=likec4EnumDirection skipwhite
syn keyword likec4PropRank     rank         nextgroup=likec4EnumRank skipwhite
syn keyword likec4PropVariant  variant      nextgroup=likec4EnumVariant skipwhite
syn keyword likec4PropMultiple multiple     nextgroup=likec4Boolean skipwhite
syn keyword likec4PropIcon     icon
      \ nextgroup=likec4Icon,likec4IconNone skipwhite

" ---------------------------------------------------------------------------
" Predicates, filters and dynamic-view control flow
" ---------------------------------------------------------------------------
syn keyword likec4Predicate include exclude where with is not and or source target
syn keyword likec4Control   loop alt opt par parallel break try catch finally
      \ if else when

syn keyword likec4Boolean  true false
syn keyword likec4Self     it this
syn keyword likec4Function rgb rgba

" ---------------------------------------------------------------------------
" Tags and colors
" ---------------------------------------------------------------------------
" Tag first, hex colour second: at a shared start position the later
" definition wins, so `#F00` reads as a colour while `#deprecated` (not a
" valid 3/4/6/8-digit hex run followed by a word boundary) reads as a tag.
syn match likec4Tag      /#[A-Za-z][A-Za-z0-9_-]*/ display
syn match likec4HexColor /#\%(\x\{8}\|\x\{6}\|\x\{4}\|\x\{3}\)\>/ display

" Icon namespaces: aws:, azure:, gcp:, tech:, bootstrap:. The colon is required
" here so a bare `none` elsewhere (a colour, an arrow head) is not swallowed;
" `icon none` is handled by the contained match below.
syn match likec4Icon /\<\%(aws\|azure\|gcp\|tech\|bootstrap\):[A-Za-z0-9_-]\+/ display
syn match likec4IconNone /\<none\>/ contained

" ---------------------------------------------------------------------------
" Relationships
" ---------------------------------------------------------------------------
" Kinded forms: -[async]-> and -[async]<->
syn region likec4RelKind matchgroup=likec4Operator
      \ start=+-\[+ end=+\]<\?->+ oneline keepend contains=likec4RelKindName
syn match  likec4RelKindName /[^]]\+/ contained

" Plain forms
syn match likec4Operator /<->\|->\|<-/ display
syn match likec4Operator /=/ display

" Dot-kind shorthand: `ui .async backend` (requires leading whitespace so that
" nested references such as `cloud.backend` are left alone).
syn match likec4RelDotKind /\s\zs\.[A-Za-z][A-Za-z0-9_-]*/ display

" Wildcards and implicit-reference sugar. Defined after the dot-kind match so
" `._` wins over it. Longest alternatives first.
syn match likec4Wildcard /\.\*\*\|\.\*\|\._\|\*\*\|\*/ display

" ---------------------------------------------------------------------------
" Numbers
" ---------------------------------------------------------------------------
syn match likec4Number /\v<\d+(\.\d+)?\%?/ display

" ---------------------------------------------------------------------------
" Highlight links -- `hi def link` only, so colorschemes stay in control.
" ---------------------------------------------------------------------------
hi def link likec4LineComment   Comment
hi def link likec4BlockComment  Comment
hi def link likec4Todo          Todo

hi def link likec4SString       String
hi def link likec4DString       String
hi def link likec4TripleSString String
hi def link likec4TripleDString String
hi def link likec4StringDelim   String
hi def link likec4Escape        SpecialChar

hi def link likec4Block         Statement
hi def link likec4Decl          Keyword
hi def link likec4Structural    Keyword

hi def link likec4Property      Identifier
hi def link likec4PropShape     Identifier
hi def link likec4PropColor     Identifier
hi def link likec4PropLine      Identifier
hi def link likec4PropArrow     Identifier
hi def link likec4PropSize      Identifier
hi def link likec4PropIconPos   Identifier
hi def link likec4PropLayout    Identifier
hi def link likec4PropRank      Identifier
hi def link likec4PropVariant   Identifier
hi def link likec4PropMultiple  Identifier
hi def link likec4PropIcon      Identifier

hi def link likec4Predicate     Conditional
hi def link likec4Control       Repeat
hi def link likec4Boolean       Boolean
hi def link likec4Self          Special
hi def link likec4Function      Function

hi def link likec4KindName      Type
hi def link likec4EnumShape     Type
hi def link likec4EnumColor     Type
hi def link likec4EnumLineStyle Type
hi def link likec4EnumArrow     Type
hi def link likec4EnumSize      Type
hi def link likec4EnumIconPos   Type
hi def link likec4EnumDirection Type
hi def link likec4EnumRank      Type
hi def link likec4EnumVariant   Type

hi def link likec4Tag           PreProc
hi def link likec4HexColor      Constant
hi def link likec4Icon          Constant
hi def link likec4IconNone      Type
hi def link likec4Number        Number

hi def link likec4Operator      Operator
hi def link likec4Wildcard      Special
hi def link likec4RelDotKind    Function
hi def link likec4RelKindName   Function

" Triple-quoted blocks can be long; look back far enough to resync inside one.
syn sync minlines=200

let b:current_syntax = 'likec4'

let &cpoptions = s:cpo_save
unlet s:cpo_save
