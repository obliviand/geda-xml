# geda-xml

Retrieved from [XML Schema and Utilities for gEDA](http://wiki.geda-project.org/geda:xml_file_formats)

## XML File Formats

This page is a starting point for discussions on using XML for commonality between gEDA applications.

One major goal of this effort is to provide advanced file format features while still maintaining backward compatibility with the existing file formats (and be able to bring an old design forward with ease if you wish).

Another main goal is to start addressing the Symbol Library Hacker task discussed at [geda:todos](http://wiki.geda-project.org/geda:todos).

Yes, this effort is self concious because of [geda:usage#can_we_change_geda_to_use_an_xml_file_format](http://wiki.geda-project.org/geda:usage#can_we_change_geda_to_use_an_xml_file_format).

The concerns expressed there will hopefully be addressed as part of this effort to minimize the impact to existing file formats, and not tie up core developer time on this work.  Specifically issues 2,3,4 and 5 are valid concerns, but they can be overcome with good design and a little bit of coding, especially if this is treated as a wrapper or evolution rather than a totally new file format.

While the initial version of the schema has both a large and small format for gschem files, it is assumed that the smaller will progress further to reduce the amount of "file bloat" associated with putting the files in this format.

While there are plenty of arguments for and against XML, it does provide one key feature that can be difficult to implement in a custom file format, and that is unification of the different data types each gEDA program expects with minimal impact to the existing programs.  What this schema currently does is separately define gschem file formats and PCB file formats.  The part schema then allows for both of these to be combined into a "part" file without change thus allowing for "heavy" parts containing both symbols and PCB elements.  It will also allow for a project to be stored in a single archive file if the user so chooses.  It thus provides a kind of wrapper functionality that maintains internal structure formats.

It also introduces file format validation making sure that the file is well-formed and also, using Schematron, makes sure that constraints on data in the file are checked.  This can be a real plus for managing parts like on gedasymbols.org when files can be "easily" validated for format and content on upload with some perl code.

[Initial git repository](http://github.com/oblivian/geda-xml/tree/master)

Right now it provides schema for gschem symbol and schematic files, and a PCB file format (adapted from parse.y).

The part/part.xsd schema is for combining the individual schemas into a part format capable of both regular and heavy parts.

convert-symbol.pl (when it is done) will write a gschem symbol to the XML format.

It also performs validation against the XML Schema itself and Schematron rules also stored in the schema files.

The XML Schema for gschem files provides for a "lightweight" file format that should allow for an overlay on the normal file reading routines in libgeda without modification.

So a line in gschem is represented as

<gs:l p="200 800 200 200 3 0 0 0 -1 -1" />

instead of

L 200 800 200 200 3 0 0 0 -1 -1

But the validation is handled by the XML parser rather than writing extra validation code.

The XML Schema makes sure the symbols are well-formed, and the Schematron makes sure the data is valid in the "p" attributes.

Work completed:

  * XML Schema for gschem, PCB and .xpart file format.
  
Work that needs to be done to get this effort really started:

  * Finish convert-symbol.pl.
  
  * Write XSLT to convert "xpart" file back to .sym/.fp format.

## IP-Xact

IP-Xact (IEEE-1685] is an industry standard xml schema for packaging and distributing IP and could be adopted by gEDA for internal use as well. Its main advantage is that it uses a component name that is guaranteed to be unique and will never have name collisions with any other IP-Xact components in the world. Each component has a four field identifier called the VLNV ( Vendor name, Library name, Component name and Version) Vendors use a URL that they own for their vendor name and no other IP-Xact file in the world will use that same name. 

The vendor name can also be the URL where the IP repository is available for download. Instantiating a VLNV  with github.com, github username and user repo name not only identifies the repository but can automatically download it if it is not already in you local design environment.

IP-Xact allows for the creation of a geda namespace and the addition of any geda specific extensions through the use of <spirit:vendorExtensions>

## Can we change gEDA to use an XML file format?

We have a recurrent debate about XML file formats on geda-user every two or three years.
I think it has to do with how long it takes us to lose our institutional memory due to churn on the mailing list.

It's unlikely the gEDA Project will ever switch to an XML file format for schematics or symbols, so get used to it.
Some reasons against XML are:

1. GEDA/gaf already has a fixed, well documented, ASCII file format, as of 2007.
   It's well used and well tested.

2. We already have a parser for our file format. It's lightweight & thoroughly debugged.

3. There are lots of legacy designs using the file format out there already.
   People would scream if we switched file formats since their old designs would become obsolete.
   And supporting two file formats – old and new – would be a major PITA.

4. XML is a generalized file format. Therefore, XML files tend to become bloated pigs.
   The gEDA file format is light & well adapted to its purpose: representing graphical
   information pertinent to schematic diagrams in electronics.

5. One purported benefit for XML files is that there are lots of open-source parsers for them available,
   making integration into libgeda trivial.
   That's the theory, but in reality the job of a parser is to analyze and parse the input, and then stick
   it into datastructures suitable for use with the rest of gschem's code.
   An open-source parser does about 1/3 of the job we need (i.e. reading & analyzing the file,
   and creating some kind of parse tree).
   The rest of the job involves putting the stuff in the parse tree into libgeda's data structures.
   That's lots of work.
   Therefore, the purported advantage of the freely-available XML parser is a chimera.
   Yes, XML may be of interest for a new program written from the ground up, but not for an existing program like gEDA.

6. GEDA developer time is better used on implementing new features like backannotation.
    Using developer time on porting our file format to XML is a sideways move which doesn't provide
    the end user any more utility, but soaks up valuable developer time.

7. The other benefit of XML is that it is more-or-less human readable.
    I'll grant that this is a valid assertion. 
    Our current file format is not readable by a human who has never read the documentation.
    However, our current file format *is* ASCII, and is completely documented, so an essential
    reason for readability - the ability to write scripts against the file - is already taken care of.
    Also, a human can certainly read the file format once he has taken the time to RTFM.
    Human readability - without knowing the file format - is a “nice to have” which isn't high on my priority list.
