module ptdownloader;

import std.stdio;
import std.file;
import std.regex;
import std.net.curl;
import std.conv;
import std.string;
import std.datetime;
import std.array;
import std.math;
import arsd.dom;


//Download all files from given URLs to given directory
void downloadLinks(string[] downloadLinks, string pathTo){
    if(downloadLinks.empty) {
        writeln("No download links found.");
        return;
    }

    foreach (string link; downloadLinks) {
        long index = lastIndexOf(link, '/');
        //if empty string or no '/' was found, ignore the current link
        if(index == -1 || link.empty) continue;
        string saveTo = link[index+1 .. $];
        //if the file already exists, ignore
        if(exists(pathTo ~ saveTo)) continue;

        //download and save to given directory
        writeln("Downloading " ~ link ~ " to " ~ pathTo ~ saveTo);
        if(!exists(pathTo)) mkdir(pathTo);
        download(link, pathTo ~ saveTo);
    }
}

// Iterate over all pages for current podcast until "No episodes found".
// Then parse all URLs containing ".mp3" from the downloaded html.
string[] findAllDownloadLinksByRegex(string podcastUrl) {
    bool done = false;
    int curPageNumber = 1;
    string urlWithParameters = podcastUrl ~ "?page=%d&append=false&sort=latest&q=";
    string[] ret = [];
    auto mp3Reg = ctRegex!("(?<=href=\\\")https?:\\/\\/?[^ ]*\\.\\w*/.+mp3", "gmi"); // Look ma, magic!

    while(!done){
        string urlForCurrentPage = format(urlWithParameters, curPageNumber);
        curPageNumber++;

        writeln("Searching download links on " ~ urlForCurrentPage);
        auto tmpReceivedHtml = get!HTTP(urlForCurrentPage);

        if(tmpReceivedHtml.indexOf("<p>No episodes found.</p>") != -1) {
            done = true;
        }
        auto matches = matchAll(tmpReceivedHtml, mp3Reg);
        
	while (!matches.empty) {
            writeln("Found " ~ matches.front()[0]);
            ret ~= to!string(matches.front()[0]);
            matches.popFront();   
        }
    }

    return ret;
}

// Iterate over all pages for current podcast until "No episodes found".
// Find and parse all download URLs by html element.
string[] findAllDownloadLinksByDom(string podcastUrl){
    bool done = false;
    int curPageNumber = 1;
    string urlWithParameters = podcastUrl ~ "?page=%d&append=false&sort=latest";
    string[] ret = [];

    while(!done) {
        string urlForCurrentPage = format(urlWithParameters, curPageNumber);
        curPageNumber++;

        writeln("Searching download links on " ~ urlForCurrentPage);
        auto tmpReceivedHtml = get!HTTP(urlForCurrentPage);

        if(tmpReceivedHtml.indexOf("<p>No episodes found.</p>") != -1) {
            done = true;
        }

        //put some tag around the downloaded html to fix an issue with dom.d
        auto document = new Document("<div>"~to!string(tmpReceivedHtml)~"</div>");
        auto links = document.querySelectorAll("a[title*=\"Download\"],a[title*=\"Herunterladen\"]");
            
        writeln("Found " ~ to!string(links.length) ~ " links");
        foreach (link; links) {
            auto found = link.getAttribute("href");           
            if(!found.empty) {
                writeln("Found " ~ found);
                ret ~= found;
            }
        }
    }

    return ret;
}

void writeHelpMessage() {
    writeln(r"Please specify the podcast URL like 
./ptdownloader https://podtail.com/podcast/NAME/
If you want to store the files in a different directory than the working dir,
./ptdownloader https://podtail.com/podcast/NAME/ ./download/directory/
Alternatively you can set the download lookup to dom, which will download anything where title='Download'
The detault will look for URLs ending with '.mp3'.
./ptdownloader dom https://podtail.com/podcast/NAME/ ./download/directory/");
}

void main(string[] args) {
    bool useRegex = true;
    string podcastUrl = "";
    string[] links;
    string dlDir = "./";
    
    args.popFront;  // get rid of name

    if(args.empty) {
        writeHelpMessage();
        return;
    }

    if(args.front() == "dom") {
        useRegex = false;
        args.popFront();
    }

    if(!args.empty) {
        podcastUrl = args.front();
        args.popFront();
    }else {
        writeHelpMessage();
    }

    if(!args.empty) {
        dlDir = args.front();
        args.popFront();
    }

    
    if(useRegex)
        links = findAllDownloadLinksByRegex(podcastUrl);
    else
        links = findAllDownloadLinksByDom(podcastUrl);
    
    downloadLinks(links, dlDir);
}
