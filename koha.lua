-- koha.lua 03/15/2018

-- koha.lua searches Koha OPACs that use the Zebra search engine. It includes buttons to do searches based on loan & journal title, article title, isxn, or oclc number.
-- It can also do an automatic search using a search priority string, in which case it will use the first field listed in the string that has a value.
-- The valid fields are title, articletitle (if an article request), isxn, and oclc.
-- The AutoSearch determines whether the search is performed automatically when a request is opened.
-- An import into request option for call no. and location info is in development.
-- This is a modified version of the WorldCat Discovery addon created by Andy Huff. 
-- Some comments and structure from discovery addon, where possible, were left in place due to the clear documentation & structure.


local settings = {};
settings.AutoSearch = GetSetting("AutoSearch");

local interfaceMngr = nil;
local kohaForm = {};
kohaForm.Form = nil;
kohaForm.Browser = nil;
kohaForm.RibbonPage = nil;

require "Atlas.AtlasHelpers";

function Init()
	interfaceMngr = GetInterfaceManager();
	
	-- Create a form
	kohaForm.Form = interfaceMngr:CreateForm("Koha Catalog", "Script");

	-- Add a browser
	kohaForm.Browser = kohaForm.Form:CreateBrowser("Koha OPAC", "Koha OPAC Search Browser", "Koha");

	-- Hide the text label
	kohaForm.Browser.TextVisible = false;
	kohaForm.Browser.WebBrowser.ScriptErrorsSuppressed = true;

	-- Since we didn't create a ribbon explicitly before creating our browser, it will have created one using the name we passed the CreateBrowser method.  We can retrieve that one and add our buttons to it.
	kohaForm.RibbonPage = kohaForm.Form:GetRibbonPage("Koha");

	-- Create the search buttons
	local button = nil;
	button = kohaForm.RibbonPage:CreateButton("Search Title", GetClientImage("Search32"), "SearchTitle", "Koha OPAC");
	if (CanSearchTitle() ~= true) then
		button.BarButton.Enabled = false;
	end
	
	button = kohaForm.RibbonPage:CreateButton("Search Article Title", GetClientImage("Search32"), "SearchArticleTitle", "Koha OPAC");
	if (CanSearchArticleTitle() ~= true) then
		button.BarButton.Enabled = false;
	end
	
	button = kohaForm.RibbonPage:CreateButton("Search ISXN", GetClientImage("Search32"), "SearchISXN", "Koha OPAC");
	if (CanSearchISXN() ~= true) then
		button.BarButton.Enabled = false;
	end
	
	button = kohaForm.RibbonPage:CreateButton("Search OCLC", GetClientImage("Search32"), "SearchOCLC", "Koha OPAC");
	if (CanSearchOCLC() ~= true) then
		button.BarButton.Enabled = false;
	end
	

	-- After we add all of our buttons and form elements, we can show the form.
	kohaForm.Form:Show();
	
	if settings.AutoSearch then
		AutoSearch();
	end
end
-- the CanSearchX functions merely see if the fields in the ILL request have data we can pull from. If not, their corresponding buttons don't appear in our form
function CanSearchTitle()
	return GetTitle() ~= ""; 
end

function CanSearchArticleTitle()
	local value = GetFieldValue("Transaction", "PhotoArticleTitle");
	if (value ~= nil and value ~= "") then 
		return true;
	end
end

function CanSearchOCLC()
	local value = GetFieldValue("Transaction", "ESPNumber")
	if (value ~= nil and value ~= "") then
		return true;
	end
	
	return false;
end

function CanSearchISXN()
	local value = GetFieldValue("Transaction", "ISSN")
	if (value ~= nil and value ~= "") then
		return true;
	end
	
	return false;
end

--Get title function is determining what title to restrieve based on request type in ILLiad.

function GetTitle()
	local title;
	if	(GetFieldValue("Transaction", "RequestType") == "Article") then
		title = GetFieldValue("Transaction", "PhotoJournalTitle");
	else
		title = GetFieldValue("Transaction", "LoanTitle");
	end
	
	if (title == nil) then
		title = "";
	end

	return title;
end

--AutoSearch function retrieves priorities listed in config.xml and compares each value to value at index 0 for match and then checks Can functions for if true.

function AutoSearch()
	SearchTitle();
   local priorities = AtlasHelpers.StringSplit(",", GetSetting("SearchPriority"));
	
	for index, priority in ipairs(priorities) do
		local priorityLower = priority:lower();
		
		if (priorityLower == "title" and CanSearchTitle()) then
			SearchTitle();
			return;
		elseif (priorityLower == "articletitle" and CanSearchArticleTitle()) then
			SearchArticleTitle();
			return;
		elseif (priorityLower == "oclc" and CanSearchOCLC()) then
			SearchOCLC();
			return;
		elseif (priorityLower == "isxn" and CanSearchISXN()) then
			SearchISXN();
			return;
		end		
	end
	
	kohaForm.Browser:Navigate(GetSetting("KohaOPACURL"));
	
end

--these are the search functions including particular prefixes specific to koha zebra

function SearchTitle()
	Search("ti:"..GetTitle());
end

function SearchArticleTitle()
	local value = GetFieldValue("Transaction", "PhotoArticleTitle");
	
	if	(value == nil) then
		value = "";
	end
	
	Search(value);
end

function SearchISXN()
	local value = GetFieldValue("Transaction", "ISSN");
	
	if (value == nil) then
		value = "";
	end
	
	local prefix;
	
	if (GetFieldValue("Transaction", "RequestType") == "Article") then
		prefix = "ns:";
	else
		prefix ="nb:";
	end
	
	Search(prefix..value);
end

function SearchOCLC()
	local value = GetFieldValue("Transaction", "ESPNumber");
	
	if	(value == nil) then
		value = "";
	end
	
	Search("Other-control-number:"..value);
end

function Search(searchTerm) --actually performs our search
	kohaForm.Browser:Navigate(GetSetting("KohaOPACURL").."/cgi-bin/koha/opac-search.pl?q="..AtlasHelpers.UrlEncode(searchTerm));
end
