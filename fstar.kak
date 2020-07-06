# Configuration
# ‾‾‾‾‾‾‾‾‾‾‾‾‾

declare-option -docstring 'path to the folder containing the nodejs implementation of the plugin' \
    str fstar_implementation_root %sh{dirname "$kak_source"}

declare-option -docstring 'path to the ipkg file that configures this project' \
    str fstar_ipkg_path "<empty>"

# Detection
# ‾‾‾‾‾‾‾‾‾

hook global BufCreate .*[.]fst %{
    set-option buffer filetype fstar

	# Mixing tabs and spaces will break
	# indentation sensitive syntax checking
    hook buffer InsertChar \t %{ try %{
      execute-keys -draft "h<a-h><a-k>\A\h+\z<ret><a-;>;%opt{indentwidth}@"
    }}

    hook buffer InsertDelete ' ' %{ try %{
      execute-keys -draft 'h<a-h><a-k>\A\h+\z<ret>i<space><esc><lt>'
    }}
}

# Highlighters
# ‾‾‾‾‾‾‾‾‾‾‾‾

add-highlighter shared/fstar regions
add-highlighter shared/fstar/code default-region group
add-highlighter shared/fstar/string       region (?<!'\\)(?<!')"                 (?<!\\)(\\\\)*"  fill string
add-highlighter shared/fstar/macro        region ^\h*?\K#                        (?<!\\)\n        fill meta
add-highlighter shared/fstar/comment      region -recurse \(\* \(\*                  \*\)            fill comment
add-highlighter shared/fstar/line_comment region --(?:[^!#$%&*+./<>?@\\\^|~=]|$) $                fill comment
add-highlighter shared/fstar/line_comment2 region \|\|\|(?:[^!#$%&*+./<>?@\\\^|~=]|$) $           fill comment

add-highlighter shared/fstar/code/ regex (?<!')\b0x+[A-Fa-f0-9]+ 0:value
add-highlighter shared/fstar/code/ regex (?<!')\b\d+([.]\d+)? 0:value

add-highlighter shared/fstar/code/ regex (?<!')\b(function|and|as|assume|assert|constraint|decreases|else|ensures|exception|external|fun|in|inherit|initializer|land|lazy|let|logic|match|method|mutable|new|of|opaque|parser|pattern|private|raise|rec|requires|try|type|virtual|when|while|with)(?!')\b 0:keyword
add-highlighter shared/fstar/code/ regex (?<!')\b(asr|lnot|lor|lsl|lsr|lxor|mod|not|string|unit|set|map|forall|exists|True|False|true|false|array|bool|char|exn|float|format|format4|nat|int|int32|int64|lazy_t|list|nativeint|option)(?!')\b 0:variable
add-highlighter shared/fstar/code/ regex (?<!')\b(sig|open|include|module)(?!')\b 0:keyword
# TODO
# add-highlighter shared/fstar/code/ regex (?<!')\b(if|in|then|else|of|case|do|data|default|proof|tactic)(?!')\b 0:keyword

# FStar Tactic - TODO: restrict tactic keywords to their context
# TODO
# add-highlighter shared/fstar/code/ regex (?<!')\b(intros|rewrite|exact|refine|trivial|let|focus|try|compute|solve|attack|reflect|fill|applyTactic)(?!')\b 0:keyword

# The complications below is because period has many uses:
# As function composition operator (possibly without spaces) like "." and "f.g"
# Hierarchical modules like "Data.Maybe"
# Qualified imports like "Data.Maybe.Just", "Data.Maybe.maybe", "Control.Applicative.<$>"
# Quantifier separator in "forall a . [a] -> [a]"
# Enum comprehensions like "[1..]" and "[a..b]" (making ".." and "Module..." illegal)

# matches uppercase identifiers:  Monad Control.Monad
# not non-space separated dot:    Just.const
add-highlighter shared/fstar/code/ regex \b([A-Z]['\w]*\.)*[A-Z]['\w]*(?!['\w])(?![.a-z]) 0:variable

# matches infix identifier: `mod` `Apa._T'M`
add-highlighter shared/fstar/code/ regex `\b([A-Z]['\w]*\.)*[\w]['\w]*` 0:operator
# matches imported operators: M.! M.. Control.Monad.>>
# not operator keywords:      M... M.->
add-highlighter shared/fstar/code/ regex \b[A-Z]['\w]*\.[~<=>|:!?/.@$*&#%+\^\-\\]+ 0:operator
# matches dot: .
# not possibly incomplete import:  a.
# not other operators:             !. .!
add-highlighter shared/fstar/code/ regex (?<![\w~<=>|:!?/.@$*&#%+\^\-\\])\.(?![~<=>|:!?/.@$*&#%+\^\-\\]) 0:operator
# matches other operators: ... > < <= ^ <*> <$> etc
# not dot: .
# not operator keywords:  @ .. -> :: ~
add-highlighter shared/fstar/code/ regex (?<![~<=>|:!?/.@$*&#%+\^\-\\])[~<=>|:!?/.@$*&#%+\^\-\\]+ 0:operator

# matches operator keywords: @ ->
add-highlighter shared/fstar/code/ regex (?<![~<=>|:!?/.@$*&#%+\^\-\\])(@|~|<-|->|=>|::|=|:|[|])(?![~<=>|:!?/.@$*&#%+\^\-\\]) 1:keyword
# matches: forall [..variables..] .
# not the variables
add-highlighter shared/fstar/code/ regex \b(forall)\b[^.\n]*?(\.) 1:keyword 2:keyword

# matches 'x' '\\' '\'' '\n' '\0'
# not incomplete literals: '\'
# not valid identifiers:   w' _'
add-highlighter shared/fstar/code/ regex \B'([^\\]|[\\]['"\w\d\\])' 0:string
# this has to come after operators so '-' etc is correct

# Commands
# ‾‾‾‾‾‾‾‾

define-command -hidden fstar-trim-indent %{
    # remove trailing white spaces
    try %{ execute-keys -draft -itersel <a-x> s \h+$ <ret> d }
}

define-command -hidden fstar-indent-on-new-line %{
    evaluate-commands -draft -itersel %{
        # copy -- comments prefix and following white spaces
        try %{ execute-keys -draft k <a-x> s ^\h*\K--\h* <ret> y gh j P }
        # preserve previous line indent
        try %{ execute-keys -draft \; K <a-&> }
        # align to first clause
        try %{ execute-keys -draft \; k x X s ^\h*(if|then|else)?\h*(([\w']+\h+)+=)?\h*(case\h+[\w']+\h+of|do|let|where)\h+\K.* <ret> s \A|.\z <ret> & }
        # filter previous line
        try %{ execute-keys -draft k : fstar-trim-indent <ret> }
        # indent after lines beginning with condition or ending with expression or =(
        try %{ execute-keys -draft \; k x <a-k> ^\h*(if)|(case\h+[\w']+\h+of|do|let|where|[=(])$ <ret> j <a-gt> }
    }
}

# Initialization
# ‾‾‾‾‾‾‾‾‾‾‾‾‾‾

hook -group fstar-highlight global WinSetOption filetype=fstar %{
    add-highlighter window/fstar ref fstar
    hook -once -always window WinSetOption filetype=.* %{ remove-highlighter window/fstar }
}

hook global WinSetOption filetype=fstar %{
    set-option window extra_word_chars '_' "'"
    hook window ModeChange insert:.* -group fstar-trim-indent  fstar-trim-indent
    hook window InsertChar \n -group fstar-indent fstar-indent-on-new-line

    hook -once -always window WinSetOption filetype=.* %{ remove-hooks window fstar-.+ }
}




