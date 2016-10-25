Translator.fieldMap = {
  # Zotero          BibTeX
  place:            { name: 'location', enc: 'literal' }
  chapter:          { name: 'chapter' }
  edition:          { name: 'edition' }
  title:            { name: 'title', caseConversion: true }
  volume:           { name: 'volume' }
  rights:           { name: 'rights' }
  ISBN:             { name: 'isbn' }
  ISSN:             { name: 'issn' }
  url:              { name: 'url' }
  DOI:              { name: 'doi' }
  shortTitle:       { name: 'shorttitle', caseConversion: true }
  abstractNote:     { name: 'abstract' }
  numberOfVolumes:  { name: 'volumes' }
  versionNumber:    { name: 'version' }
  conferenceName:   { name: 'eventtitle' }
  numPages:         { name: 'pagetotal' }
  type:             { name: 'type' }
}

Translator.typeMap = {
  # BibTeX                            Zotero
  'book booklet manual proceedings':  'book'
  'incollection inbook':              'bookSection'
  'article misc':                     'journalArticle magazineArticle newspaperArticle'
  thesis:                             'thesis'
  letter:                             'email letter'
  movie:                              'film'
  artwork:                            'artwork'
  # =online because someone thinks that any object property starting with 'on' on any kind of object installs an event handler on a DOM
  # node
  '=online':                          'blogPost forumPost webpage'
  inproceedings:                      'conferencePaper'
  report:                             'report'
  legislation:                        'statute bill'
  jurisdiction:                       'case hearing'
  patent:                             'patent'
  audio:                              'audioRecording podcast radioBroadcast'
  video:                              'videoRecording tvBroadcast'
  software:                           'computerProgram'
  unpublished:                        'manuscript presentation'
  inreference:                        'encyclopediaArticle dictionaryEntry'
  misc:                               'interview map instantMessage document'
}

Translator.fieldEncoding = {
  url: 'url'
  doi: 'verbatim'
  eprint: 'verbatim'
  eprintclass: 'verbatim'
  crossref: 'raw'
  xdata: 'raw'
  xref: 'raw'
  entrykey: 'raw'
  childentrykey: 'raw'
  verba: 'verbatim'
  verbb: 'verbatim'
  verbc: 'verbatim'
}

class DateField
  constructor: (date, locale, formatted, literal) ->
    parsed = Zotero.BetterBibTeX.parseDateToObject(date, locale, Translator.biblatexExtendedDateFormat)

    switch
      when !parsed
        @field = {}

      when parsed.literal
        @field = { name: literal, value: date }

      when (parsed.extended || parsed.year || parsed.empty) && (parsed.extended_end || parsed.year_end || parsed.empty_end)
        @field = { name: formatted, value: @format(parsed) + '/' + @format(parsed, '_end') }

      when parsed.year || parsed.extended
        @field = { name: formatted, value: @format(parsed) }

      else
        @field = {}

  pad: (v, pad) ->
    return v if v.length >= pad.length
    return (pad + v).slice(-pad.length)

  year: (y) ->
    if Math.abs(y) > 999
      return '' + y
    else
      return (if y < 0 then '-' else '-') + ('000' + Math.abs(y)).slice(-4)

  format: (v, suffix = '') ->
    _v = {}
    for f in ['circa', 'uncertain', 'extended', 'empty', 'year', 'month', 'day']
      _v[f] = v["#{f}#{suffix}"]

    switch
      when _v.empty                       then  date = ''
      when _v.extended                    then  date = _v.extended
      when _v.year && _v.month && _v.day  then  date = "#{@year(_v.year)}-#{@pad(_v.month, '00')}-#{@pad(_v.day, '00')}"
      when _v.year && _v.month            then  date = "#{@year(_v.year)}-#{@pad(_v.month, '00')}"
      else                                      date = @year(_v.year)

    if Translator.biblatexExtendedDateFormat
      date += '?' if _v.uncertain
      # well this is fairly dense... the date field is not an verbatim field, so the 'circa' symbol ('~') ought to mean a
      # NBSP... but some magic happens in that field (always with the magic, BibLaTeX...). But hey, if I insert an NBSP,
      # guess what that gets translated to!
      date += '\u00A0' if _v.circa
    return date

Reference::requiredFields =
  article: ['author', 'title', 'journaltitle', 'year/date']
  book: ['author', 'title', 'year/date']
  mvbook: ['book']
  inbook: ['author', 'title', 'booktitle', 'year/date']
  bookinbook: ['inbook']
  suppbook: ['inbook']
  booklet: ['author/editor', 'title', 'year/date']
  collection: ['editor', 'title', 'year/date']
  mvcollection: ['collection']
  incollection: ['author', 'title', 'booktitle', 'year/date']
  suppcollection: ['incollection']
  manual: ['author/editor', 'title', 'year/date']
  misc: ['author/editor', 'title', 'year/date']
  online: ['author/editor', 'title', 'year/date', 'url']
  patent: ['author', 'title', 'number', 'year/date']
  periodical: ['editor', 'title', 'year/date']
  suppperiodical: ['article']
  proceedings: ['title', 'year/date']
  mvproceedings: ['proceedings']
  inproceedings: ['author', 'title', 'booktitle', 'year/date']
  reference: ['collection']
  mvreference: ['collection']
  inreference: ['incollection']
  report: ['author', 'title', 'type', 'institution', 'year/date']
  thesis: ['author', 'title', 'type', 'institution', 'year/date']
  unpublished: ['author', 'title', 'year/date']

  # semi aliases (differing fields)
  mastersthesis: ['author', 'title', 'institution', 'year/date']
  techreport: ['author', 'title', 'institution', 'year/date']

Reference::requiredFields.conference = Reference::requiredFields.inproceedings
Reference::requiredFields.electronic = Reference::requiredFields.online
Reference::requiredFields.phdthesis = Reference::requiredFields.mastersthesis
Reference::requiredFields.www = Reference::requiredFields.online

Reference::addCreators = ->
  return unless @item.creators and @item.creators.length

  creators = {
    author: []
    bookauthor: []
    commentator: []
    editor: []
    editora: []
    editorb: []
    holder: []
    translator: []
    scriptwriter: []
    director: []
  }
  for creator in @item.creators
    kind = switch creator.creatorType
      when 'director'
        # 365.something
        if @referencetype in ['video', 'movie']
          'director'
        else
          'author'
      when 'author', 'interviewer', 'programmer', 'artist', 'podcaster', 'presenter'
        'author'
      when 'bookAuthor'
        'bookauthor'
      when 'commenter'
        'commentator'
      when 'editor'
        'editor'
      when 'inventor'
        'holder'
      when 'translator'
        'translator'
      when 'seriesEditor'
        'editorb'
      when 'scriptwriter'
        # 365.something
        if @referencetype in ['video', 'movie']
          'scriptwriter'
        else
          'editora'

      else
        'editora'

    creators[kind].push(creator)

  for own field, value of creators
    @remove(field)
    @add({ name: field, value: value, enc: 'creators' })

  @add({ editoratype: 'collaborator' }) if creators.editora.length > 0
  @add({ editorbtype: 'redactor' }) if creators.editorb.length > 0

doExport = ->
  Zotero.write('\n')
  while item = Translator.nextItem()
    ref = new Reference(item)

    ref.referencetype = 'inbook' if item.itemType == 'bookSection' and ref.hasCreator('bookAuthor')
    ref.referencetype = 'collection' if item.itemType == 'book' and not ref.hasCreator('author') and ref.hasCreator('editor')
    ref.referencetype = 'mvbook' if ref.referencetype == 'book' and item.numberOfVolumes

    if m = item.url?.match(/^http:\/\/www.jstor.org\/stable\/([\S]+)$/i)
      ref.add({ eprinttype: 'jstor'})
      ref.add({ eprint: m[1] })
      delete item.url
      ref.remove('url')

    if m = item.url?.match(/^http:\/\/books.google.com\/books?id=([\S]+)$/i)
      ref.add({ eprinttype: 'googlebooks'})
      ref.add({ eprint: m[1] })
      delete item.url
      ref.remove('url')

    if m = item.url?.match(/^http:\/\/www.ncbi.nlm.nih.gov\/pubmed\/([\S]+)$/i)
      ref.add({ eprinttype: 'pubmed'})
      ref.add({ eprint: m[1] })
      delete item.url
      ref.remove('url')

    for eprinttype in ['pmid', 'arxiv', 'jstor', 'hdl', 'googlebooks']
      if ref.has[eprinttype]
        if not ref.has.eprinttype
          ref.add({ eprinttype: eprinttype})
          ref.add({ eprint: ref.has[eprinttype].value })
        ref.remove(eprinttype)

    if item.archive and item.archiveLocation
      archive = true
      switch item.archive.toLowerCase()
        when 'arxiv'
          ref.add({ eprinttype: 'arxiv' })           unless ref.has.eprinttype
          ref.add({ eprintclass: item.callNumber })

        when 'jstor'
          ref.add({ eprinttype: 'jstor' })           unless ref.has.eprinttype

        when 'pubmed'
          ref.add({ eprinttype: 'pubmed' })          unless ref.has.eprinttype

        when 'hdl'
          ref.add({ eprinttype: 'hdl' })             unless ref.has.eprinttype

        when 'googlebooks', 'google books'
          ref.add({ eprinttype: 'googlebooks' })     unless ref.has.eprinttype

        else
          archive = false

      if archive
        ref.add({ eprint: item.archiveLocation })    unless ref.has.eprint

    ref.add({ langid: ref.language })

    ref.add({ number: item.seriesNumber || item.number })
    ref.add({ name: (if isNaN(parseInt(item.issue)) || (( '' + parseInt(item.issue)) != ('' + item.issue))  then 'issue' else 'number'), value: item.issue })

    switch item.itemType
      when 'case', 'gazette'
        ref.add({ name: 'journaltitle', value: item.reporter, preserveBibTeXVariables: true })
      when 'statute'
        ref.add({ name: 'journaltitle', value: item.code, preserveBibTeXVariables: true })

    if item.publicationTitle
      switch item.itemType
        when 'bookSection', 'conferencePaper', 'dictionaryEntry', 'encyclopediaArticle'
          ref.add({ name: 'booktitle', value: item.bookTitle || item.publicationTitle, preserveBibTeXVariables: true, caseConversion: true})

        when 'magazineArticle', 'newspaperArticle'
          ref.add({ name: 'journaltitle', value: item.publicationTitle, preserveBibTeXVariables: true})
          ref.add({ journalsubtitle: item.section }) if item.itemType == 'newspaperArticle'

        when 'journalArticle'
          if ref.isBibVar(item.publicationTitle)
            ref.add({ name: 'journaltitle', value: item.publicationTitle, preserveBibTeXVariables: true })
          else
            abbr = Zotero.BetterBibTeX.journalAbbrev(item)
            if Translator.useJournalAbbreviation && abbr
              ref.add({ name: 'journal', value: abbr, preserveBibTeXVariables: true })
            else if Translator.BetterBibLaTeX && item.publicationTitle.match(/arxiv:/i)
              ref.add({ name: 'journaltitle', value: item.publicationTitle, preserveBibTeXVariables: true })
              ref.add({ name: 'shortjournal', value: abbr, preserveBibTeXVariables: true })
            else
              ref.add({ name: 'journaltitle', value: item.publicationTitle, preserveBibTeXVariables: true })
              ref.add({ name: 'shortjournal', value: abbr, preserveBibTeXVariables: true })

        else
          ref.add({ journaltitle: item.publicationTitle}) if ! ref.has.journaltitle && item.publicationTitle != item.title

    ref.add({ name: 'booktitle', value: item.bookTitle || item.encyclopediaTitle || item.dictionaryTitle || item.proceedingsTitle, caseConversion: true }) if not ref.has.booktitle
    ref.add({ name: 'booktitle', value: item.websiteTitle || item.forumTitle || item.blogTitle || item.programTitle, caseConversion: true }) if ref.referencetype in ['movie', 'video'] and not ref.has.booktitle

    if item.multi?._keys?.title && (main = item.multi?.main?.title || item.language)
      languages = Object.keys(item.multi._keys.title).filter((lang) -> lang != main)
      main += '-'
      languages.sort((a, b) ->
        return 0 if a == b
        return -1 if a.indexOf(main) == 0 && b.indexOf(main) != 0
        return 1 if a.indexOf(main) != 0 && b.indexOf(main) == 0
        return -1 if a < b
        return 1
      )
      for lang, i in languages
        ref.add(name: (if i == 0 then 'titleaddon' else 'user' + String.fromCharCode('d'.charCodeAt() + i)), value: item.multi._keys.title[lang])

    ref.add({ series: item.seriesTitle || item.series })

    switch item.itemType
      when 'report', 'thesis'
        ref.add({ name: 'institution', value: item.institution || item.publisher || item.university, enc: 'literal' })

      when 'case', 'hearing'
        ref.add({ name: 'institution', value: item.court, enc: 'literal' })

      else
        ref.add({ name: 'publisher', value: item.publisher, enc: 'literal' })

    switch item.itemType
      when 'letter' then ref.add({ name: 'type', value: item.letterType || 'Letter', caseConversion: true, replace: true })

      when 'email'  then ref.add({ name: 'type', value: 'E-mail', caseConversion: true, replace: true })

      when 'thesis'
        thesistype = item.thesisType?.toLowerCase()
        if thesistype in ['phdthesis', 'mastersthesis']
          ref.referencetype = thesistype
          ref.remove('type')
        else
          ref.add({ name: 'type', value: item.thesisType, caseConversion: true, replace: true })

      when 'report'
        if (item.type || '').toLowerCase().trim() == 'techreport'
          ref.referencetype = 'techreport'
        else
          ref.add({ name: 'type', value: item.type, caseConversion: true, replace: true })

      else
        ref.add({ name: 'type', value: item.type || item.websiteType || item.manuscriptType, caseConversion: true, replace: true })

    ref.add({ howpublished: item.presentationType || item.manuscriptType })

    ref.add({ name: 'note', value: item.meetingName, allowDuplicates: true, html: true })

    ref.addCreators()

    ref.add({ urldate: Zotero.Utilities.strToISO(item.accessDate) }) if item.accessDate && item.url

    if item.date
      if m = item.date.match(/^\[([0-9]+)\]\s+(.*)/)
        ref.add({ origdate: m[1] })
        ref.add((new DateField(m[2], item.language, 'date', 'year')).field)
      else
        ref.add((new DateField(item.date, item.language, 'date', 'year')).field)

    switch
      when item.pages
        ref.add({ pages: item.pages.replace(/[-\u2012-\u2015\u2053]+/g, '--' )})
      when item.firstPage && item.lastPage
        ref.add({ pages: "#{item.firstPage}--#{item.lastPage}" })
      when item.firstPage
        ref.add({ pages: "#{item.firstPage}" })

    ref.add({ name: (if ref.has.note then 'annotation' else 'note'), value: item.extra, allowDuplicates: true })
    ref.add({ name: 'keywords', value: item.tags, enc: 'tags' })

    if item.notes and Translator.exportNotes
      for note in item.notes
        ref.add({ name: 'annotation', value: Zotero.Utilities.unescapeHTML(note.note), allowDuplicates: true, html: true })

    ###
    # 'juniorcomma' needs more thought, it isn't for *all* suffixes you want this. Or even at all.
    #ref.add({ name: 'options', value: (option for option in ['useprefix', 'juniorcomma'] when ref[option]).join(',') })
    ###
    ref.add({ options: 'useprefix=true' }) if ref.useprefix

    ref.add({ name: 'file', value: item.attachments, enc: 'attachments' })

    if item.volumeTitle # #381
      Translator.debug('volumeTitle: true, itemType:', item.itemType, 'has:', Object.keys(ref.has))
      if item.itemType == 'book' && ref.has.title
        Translator.debug('volumeTitle: for book, itemType:', item.itemType, 'has:', Object.keys(ref.has))
        ref.add({name: 'maintitle', value: item.volumeTitle, caseConversion: true })
        [ref.has.title.bibtex, ref.has.maintitle.bibtex] = [ref.has.maintitle.bibtex, ref.has.title.bibtex]
        [ref.has.title.value, ref.has.maintitle.value] = [ref.has.maintitle.value, ref.has.title.value]

      if item.itemType == 'bookSection' && ref.has.booktitle
        Translator.debug('volumeTitle: for bookSection, itemType:', item.itemType, 'has:', Object.keys(ref.has))
        ref.add({name: 'maintitle', value: item.volumeTitle, caseConversion: true })
        [ref.has.booktitle.bibtex, ref.has.maintitle.bibtex] = [ref.has.maintitle.bibtex, ref.has.booktitle.bibtex]
        [ref.has.booktitle.value, ref.has.maintitle.value] = [ref.has.maintitle.value, ref.has.booktitle.value]

    ref.complete()

  Translator.complete()
  Zotero.write('\n')
  return
