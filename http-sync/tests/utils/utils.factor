! A mixed bag of useful stuff not found anywhere else
USING:
    accessors
    arrays
    assocs
    continuations
    fry
    html.parser.analyzer
    interpolate interpolate.private
    io.streams.string
    kernel
    namespaces
    present
    sequences
    splitting
    xml xml.entities.html ;
IN: http-sync.tests.utils

: categorize ( seq quot -- assoc )
    '[
        dup @
        [ { } 2array suffix ]
        [ [ unclip-last first2 ] dip suffix 2array suffix ] if
    ] { } swap reduce ; inline

: interpolate-string ( assoc str -- str' )
    parse-interpolate [
        dup interpolate-var? [ name>> of present ] [ nip ] if
    ] with map "" join ;

: find-between-has-class ( vector class -- vector' )
    '[ "class" attribute dup "" ? " " split _ swap member? ]
    find-between-all ;

: html-vector>text ( vector -- text )
    [ text>> ] map sift " " join ;

: replace-entities ( html-str -- str )
    [ [ string>xml-chunk ] with-html-entities first ] [ drop ] recover ;
