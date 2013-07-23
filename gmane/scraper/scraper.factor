USING:
    accessors
    arrays
    calendar.format
    combinators
    formatting
    fry
    gmane.db
    html.parser html.parser.analyzer
    kernel
    math
    regexp
    sequences sequences.repeating
    splitting
    strings
    unicode.categories
    xml xml.entities.html
    ;
IN: gmane.scraper

: mail-url ( n str -- str )
    swap "http://article.gmane.org/gmane.%s/%d" sprintf ;

: replace-entities ( html-str -- str )
    '[ _ string>xml-chunk ] with-html-entities first ;

: tag-vector>string ( vector -- string )
    ! Special quoting used in html mails. TODO: different parser for
    ! html and plain text.
    dup [ name>> "blockquote" = ] find-between-all swap
    [
      dup
      [
        [ dup empty? not [ " " prepend ] when ] change-text
      ] map replace
    ] reduce
    ! Translate br tags to newlines.
    [ dup name>> "br" = [ text >>name "\n" >>text ] when ] map
    ! Filter away comments and non-text nodes
    [ [ text>> ] [ name>> comment = not ] bi and ] filter

    [ text>> ] map concat
    ! Fix entities &lt; is replaced with < and so on.
    replace-entities
    ! Replace consecutive repetitions of \n so that there is at most
    ! two after each other. This is done because html formatted mails
    ! contains redundant new lines that does not look good when
    ! rendered as plain text.
    R/ \n\n+/ "\n\n" re-replace
    [ blank? ] trim ;

! Well it's not very pretty but it manages to produce good-looking
! text renderings of html mails... most of the time.
TUPLE: parser-state lines pre? indent n-blanks ;

: new-line ( state -- state' )
    dup n-blanks>> 2 =
    [ [ but-last ] change-lines ]
    [ [ 1 + ] change-n-blanks ] if
    dup indent>> '[ _ "" 2array suffix ] change-lines ;

: add-text ( state text -- state' )
    '[ unclip-last first2 _ append 2array suffix ] change-lines
    0 >>n-blanks ;

: add-lines ( state lines -- state' )
    dupd [ [ indent>> ] dip 2array ] with map '[ _ append ] change-lines ;

: process-tag ( state tag -- state' )
    dup [ name>> ] keep closing?>> 2array
    {
        { { "p" f } [ drop new-line ] }
        { { "p" t } [ drop new-line ] }
        { { "div" f } [ drop new-line ] }
        { { "br" f } [ drop new-line ] }
        ! Webkit css mandates two blank lines for blockquotes.
        { { "blockquote" f } [ drop [ 1 + ] change-indent new-line new-line ] }
        { { "blockquote" t } [ drop [ 1 - ] change-indent ] }
        {
            { text f }
            [
                text>>
                replace-entities
                swap dup pre?>>
                [ swap add-text ]
                ! [ swap [ CHAR: \n = ] trim string-lines add-lines ]
                [ swap "\n" "" replace add-text ] if
            ]
        }
        ! Content in pre tags require special treatment because
        ! newlines are significant.
        { { "pre" f } [ drop t >>pre? new-line ] }
        {
          { "pre" t }
          [ drop f >>pre? ]
        }
        [ 2drop ]
    } case ;

: compress-br ( vector -- vector' )
  "br" H{ } f f tag boa "div" H{ } f t tag boa 2array
  "div" H{ } f t tag boa 1array replace
  "br" H{ } f f tag boa "blockquote" H{ } f t tag boa 2array
  "blockquote" H{ } f t tag boa 1array replace ;

: tag-vector>logical-lines ( vector -- seq )
    remove-blank-text compress-br
    { } f 0 0 parser-state boa [ process-tag ] reduce lines>>
    ! May be empty junk lines at head and tail
    [ second empty? ] trim ;

: logical-lines>string ( seq -- str )
    [ first2 [ [ " > " ] replicate concat ] dip append ] map "\n" join ;

: remove-all ( seq subseqs -- seq )
    swap [ { } replace ] reduce ;

: select-mail-body ( html -- html' )
    "bodytd" find-by-class-between dup
    [
        [ name>> "script" = ] [ "headers" html-class? ] bi or
    ] find-between-all remove-all ;

: parse-mail-header ( html header -- text )
    [ tag-vector>string ] dip
    ": " append dup "[^\n]+" append <regexp> swapd first-match
    swap "" replace "\t" "" replace ;

: parse-mail ( n str -- mail/f )
    2dup mail-url scrape-html nip dup length 1 =
    [ 3drop f ]
    [
        [ f -rot ] dip
        {
            [ "Date" parse-mail-header ymdhms>timestamp ]
            [ "From" parse-mail-header ]
            [ "Subject" parse-mail-header ]
            [ select-mail-body tag-vector>string ]
        } cleave mail boa
    ] if ;
