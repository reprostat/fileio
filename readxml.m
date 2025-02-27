function [tree, RootName, DOMnode] = readxml(varargin)
%XML_READ reads xml files and converts them into Matlab's struct tree.
%
% DESCRIPTION
% tree = readxml(xmlfile) reads 'xmlfile' into data structure 'tree'
%
% tree = readxml(xmlfile, Name, Value) reads 'xmlfile' into data structure 'tree'
% according to your preferences
%
% [tree, RootName, DOMnode] = readxml(xmlfile) get additional information
% about XML file
%
% INPUT:
%  xmlfile	URL or filename of xml file to read
%  Name - Value
%    ItemName - default 'item' - name of a special tag used to itemize
%                    cell arrays
%    ReadAttr - default true - allow reading attributes
%    ReadSpec - default true - allow reading special nodes
%    Str2Num  - default true - convert strings that look like numbers
%                   to numbers
%    NoCells  - default true - force output to have no cell arrays
%    Debug    - default false - show mode specific error messages
%    NumLevels- default infinity - how many recursive levels are
%      allowed. Can be used to speed up the function by prunning the tree.
%    RootOnly - default true - output variable 'tree' corresponds to
%      xml file root element, otherwise it correspond to the whole file.
%    ItemID   - default 'name' - name of the field identifying items,
%      Used for matching array items during updating.
% OUTPUT:
%  tree         tree of structs and/or cell arrays corresponding to xml file
%  RootName     XML tag name used for root (top level) node.
%               Optionally it can be a string cell array storing: Name of
%               root node, document "Processing Instructions" data and
%               document "comment" string
%  DOMnode      output of xmlread
%
% DETAILS:
% Function readxml first calls MATLAB's xmlread function and than
% converts its output ('Document Object Model' tree of Java objects)
% to tree of MATLAB struct's. The output is in format of nested structs
% and cells. In the output data structure field names are based on
% XML tags, except in cases when tags produce illegal variable names.
%
% Several special xml node types result in special tags for fields of
% 'tree' nodes:
%  - node.CONTENT - stores data section of the node if other fields are
%    present. Usually data section is stored directly in 'node'.
%  - node.ATTRIBUTE.name - stores node's attribute called 'name'.
%  - node.COMMENT - stores node's comment section (string). For global
%    comments see "RootName" output variable.
%  - node.CDATA_SECTION - stores node's CDATA section (string).
%  - node.PROCESSING_INSTRUCTIONS - stores "processing instruction" child
%    node. For global "processing instructions" see "RootName" output variable.
%  - other special node types like: document fragment nodes, document type
%   nodes, entity nodes, notation nodes and processing instruction nodes
%   will be treated like regular nodes
%
% EXAMPLES:
%   MyTree=[];
%   MyTree.MyNumber = 13;
%   MyTree.MyString = 'Hello World';
%   xml_write('test.xml', MyTree);
%   [tree treeName] = readxml ('test.xml');
%   disp(treeName)
%
% See also:
%   writexml, xmlread, xmlwrite
%
% Written by Jarek Tuszynski, SAIC, jaroslaw.w.tuszynski_at_saic.com
%
% References:
%  - Function inspired by Example 3 found in xmlread function.
%  - Output data structures inspired by xml_toolbox structures.
%
% Rhordi Cusack 13/2/2010 - took out date conversion option in str2var as this
%   erroneously leaves 3-double vectors as strings
% Rhordi Cusack - add support for XML arrays
% Tibor Auer - add support for arrays of structures with missing fields
% Tibor Auer - Octave compatibility
% Tibor Auer - add inputParser

    tree      = [];
    RootName  = [];

    %% default preferences
    defaultItemName  = 'item'; % name of a special tag used to itemize cell arrays
    defaultReadAttr  = true;   % allow reading attributes
    defaultReadSpec  = true;   % allow reading special nodes: comments, CData, etc.
    defaultStr2Num   = true;   % convert strings that look like numbers to numbers
    defaultNoCells   = true;   % force output to have no cell arrays
    defaultNumLevels = 1e10;   % number of recurence levels
    defaultRootOnly  = true;   % return root node  with no top level special nodes
    defaultItemID    = 'name'; % name of the field identifying items
    defaultDebug     = false;  % show specific errors (true) or general (false)?

    %% read user preferences
    argParse = inputParser;
    argParse.addRequired('xmlfile',@ischar);
    argParse.addParameter('ItemName',defaultItemName,@ischar);
    argParse.addParameter('ReadAttr',defaultReadAttr,@(x) islogical(x) || isnumeric(x));
    argParse.addParameter('ReadSpec',defaultReadSpec,@(x) islogical(x) || isnumeric(x));
    argParse.addParameter('Str2Num',defaultStr2Num,@(x) islogical(x) || isnumeric(x));
    argParse.addParameter('NoCells',defaultNoCells,@(x) islogical(x) || isnumeric(x));
    argParse.addParameter('NumLevels',defaultNumLevels,@isnumeric);
    argParse.addParameter('RootOnly',defaultRootOnly,@(x) islogical(x) || isnumeric(x));
    argParse.addParameter('ItemID',defaultItemID,@ischar);
    argParse.addParameter('Debug',defaultDebug,@(x) islogical(x) || isnumeric(x));
    argParse.parse(varargin{:});
    DPref = argParse.Results;

    if (ischar(DPref.xmlfile)) % if xmlfile is a string
      DPref.xmlfile = readLink(DPref.xmlfile);
      if (DPref.Debug)
        DOMnode = getDOMnode(DPref.xmlfile);
      else
        try
          DOMnode = getDOMnode(DPref.xmlfile);
        catch E
          error('Failed to read XML file %s: %s.',DPref.xmlfile, E.message);
        end
      end
      Node = DOMnode.getFirstChild;
    else %if xmlfile is not a string than maybe it is a DOMnode already
      try
        Node = DPref.xmlfile.getFirstChild;
        DOMnode = DPref.xmlfile;
      catch
        error('Input variable xmlfile has to be a string or DOM node.');
      end
    end

    %% Find the Root node. Also store data from Global Comment and Processing
    %  Instruction nodes, if any.
    GlobalTextNodes = cell(1,3);
    GlobalProcInst  = [];
    GlobalComment   = [];
    GlobalDocType   = [];
    while (~isempty(Node))
      if (Node.getNodeType==Node.ELEMENT_NODE)
        RootNode=Node;
      elseif (Node.getNodeType==Node.PROCESSING_INSTRUCTION_NODE)
        data   = strtrim(char(Node.getData));
        target = strtrim(char(Node.getTarget));
        GlobalProcInst = [target, ' ', data];
        GlobalTextNodes{2} = GlobalProcInst;
      elseif (Node.getNodeType==Node.COMMENT_NODE)
        GlobalComment = strtrim(char(Node.getData));
        GlobalTextNodes{3} = GlobalComment;
        %   elseif (Node.getNodeType==Node.DOCUMENT_TYPE_NODE)
        %     GlobalTextNodes{4} = GlobalDocType;
      end
      Node = Node.getNextSibling;
    end

    %% parse xml file through calls to recursive DOMnode2struct function
    if (DPref.Debug)   % in debuging mode allow crashes
      [tree RootName] = DOMnode2struct(RootNode, DPref, 1);
    else         % in normal mode do not allow crashes
      try
        [tree RootName] = DOMnode2struct(RootNode, DPref, 1);
      catch
        error('Unable to parse XML file %s.',DPref.xmlfile);
      end
    end

    %% If there were any Global Text nodes than return them
    if (~DPref.RootOnly)
      if (~isempty(GlobalProcInst) && DPref.ReadSpec)
        t.PROCESSING_INSTRUCTION = GlobalProcInst;
      end
      if (~isempty(GlobalComment) && DPref.ReadSpec)
        t.COMMENT = GlobalComment;
      end
      if (~isempty(GlobalDocType) && DPref.ReadSpec)
        t.DOCUMENT_TYPE = GlobalDocType;
      end
      t.(RootName) = tree;
      tree=t;
    end
    if (~isempty(GlobalTextNodes))
      GlobalTextNodes{1} = RootName;
      RootName = GlobalTextNodes;
    end

    tree = expand_tree(tree,DPref);
    if isfield(tree,'ATTRIBUTE'), tree = rmfield(tree,'ATTRIBUTE'); end
end

function DOMnode = getDOMnode(xmlfile)
    if isOctave() % Octave
        javaaddpath(fullfile(fileparts(mfilename('fullpath')),'xerces','xercesImpl.jar'));
        javaaddpath(fullfile(fileparts(mfilename('fullpath')),'xerces','xml-apis.jar'));
        pkg('load','io');

        % read xml file using Octave function
        DOMnode = xmlread(xmlfile);
    else % MATLAB
        %% Check Matlab Version
        v = ver('MATLAB');
        v = str2double(regexp(v.Version, '\d+.\d','match','once'));
        if (v<7.1)
          error('Your MATLAB version is too old. You need version 7.1 or newer.');
        end

        % read xml file using Matlab function
        parserFactory = javaMethod('newInstance',...
            'javax.xml.parsers.DocumentBuilderFactory');
        javaMethod('setXIncludeAware',parserFactory,true);
        javaMethod('setNamespaceAware',parserFactory,true);
        p = javaMethod('newDocumentBuilder',parserFactory);
        DOMnode = xmlread(xmlfile,p);
    end
end

%% =======================================================================
%  === DOMnode2struct Function ===========================================
%  =======================================================================
function [s sname LeafNode] = DOMnode2struct(node, Pref, level)
    [sname LeafNode] = NodeName(node);
    s = [];

    %% === read in node data =================================================
    if (LeafNode)
      if (LeafNode>1 && ~Pref.ReadSpec), LeafNode=-1; end % tags only so ignore special nodes
      if (LeafNode>0) % supported leaf node types
        s = strtrim(char(node.getData));
        if (LeafNode==1 && Pref.Str2Num), s=str2var(s); end
      end
      if (LeafNode==3) % ProcessingInstructions need special treatment
        target = strtrim(char(node.getTarget));
        s = [target, ' ', s];
      end
      return
    end
    if (level>Pref.NumLevels+1), return; end

    %% === read in children nodes ============================================
    if (node.hasChildNodes)        % children present
      Child  = node.getChildNodes; % create array of children nodes
      nChild = Child.getLength;    % number of children

      % --- pass 1: how many children with each name -----------------------
      f = [];
      for iChild = 1:nChild        % read in each child
        [cname cLeaf] = NodeName(Child.item(iChild-1));
        if (cLeaf<0), continue; end % unsupported leaf node types
        if (~isfield(f,cname)),
          f.(cname)=0;           % initialize first time I see this name
        end
        f.(cname) = f.(cname)+1; % add to the counter
      end                        % end for iChild
      % text_nodes become CONTENT & for some reason current xmlread 'creates' a
      % lot of empty text fields so f.CONTENT value should not be trusted
      if (isfield(f,'CONTENT') && f.CONTENT>2), f.CONTENT=2; end

      % --- pass 2: store all the children ---------------------------------
      for iChild = 1:nChild        % read in each child
        [c cname cLeaf] = DOMnode2struct(Child.item(iChild-1), Pref, level+1);
        if (cLeaf && isempty(c))   % if empty leaf node than skip
          continue;                % usually empty text node or one of unhandled node types
        elseif (nChild==1 && cLeaf==1)
          s=c;                     % shortcut for a common case
        else                       % if normal node
          if (level>Pref.NumLevels), continue; end
          n = f.(cname);           % how many of them in the array so far?
          if (~isfield(s,cname))   % encountered this name for the first time
            if (n==1)              % if there will be only one of them ...
              s.(cname) = c;       % than save it in format it came in
            else                   % if there will be many of them ...
              s.(cname) = cell(1,n);
              s.(cname){1} = c;    % than save as cell array
            end
            f.(cname) = 1;         % reset the counter
          else                     % already have seen this name
            s.(cname){n+1} = c;    % add to the array
            f.(cname) = n+1;       % add to the array counter
          end
        end
      end   % for iChild
    end % end if (node.hasChildNodes)

    %% === Post-processing of struct's =======================================
    if (isstruct(s))
      fields = fieldnames(s);
      nField = length(fields);

      % --- Post-processing: convert 'struct of arrays' to 'array of struct'
      vec = zeros(size(fields));
      for i=1:nField, vec(i) = f.(fields{i}); end
      if (numel(vec)>1 && vec(1)>1 && var(vec)==0)    % convert from struct of
        s = cell2struct(struct2cell(s), fields, 1); % arrays to array of struct
      end % if anyone knows better way to do above conversion please let me know.

      % --- Post-processing: remove special 'item' tags ---------------------
      if (isfield(s,Pref.ItemName))
        if (nField==1)
          s = s.(Pref.ItemName);         % only child: remove a level
        else
          s.CONTENT = s.(Pref.ItemName); % other children/attributes present use CONTENT
          s = rmfield(s,Pref.ItemName);
        end
      end

      % --- Post-processing: clean up CONTENT tags ---------------------
      if (isfield(s,'CONTENT'))
        if (iscell(s.CONTENT)) % && all(cellfun('isempty', s.CONTENT(2:end))))
          %msk = ~cellfun('isempty', s.CONTENT)
          %s.CONTENT = s.CONTENT(msk); % delete empty cells
          x = s.CONTENT;
          for i=length(x):-1:1, if ~isempty(x{i}), break; end; end
          if (i==1)
            s.CONTENT = x{1};   % delete cell structure
          else
            s.CONTENT = x(1:i); % delete empty cells
          end
        end
        if (nField==1)
          s = s.CONTENT;      % only child: remove a level
        end
      end
    end

    %% === Read in attributes ===============================================
    if (node.hasAttributes && Pref.ReadAttr)
      if (~isstruct(s)),               % make into struct if is not already
        ss.CONTENT=s;
        s=ss;
      end
      Attr  = node.getAttributes;     % list of all attributes
      for iAttr = 1:Attr.getLength    % for each attribute
        name  = char(Attr.item(iAttr-1).getName);  % attribute name
        name  = str2varName(name);    % fix name if needed
        value = char(Attr.item(iAttr-1).getValue); % attribute value
        if (Pref.Str2Num), value = str2var(value); end % convert to number if possible
        s.ATTRIBUTE.(name) = value;   % save again
      end                             % end iAttr loop
    end % done with attributes

    %% === Post-processing: convert 'cells of structs' to 'arrays of structs'
    if (isstruct(s))
      fields = fieldnames(s);     % get field names
      for iItem=1:length(s)       % for each struct in the array - usually one
        for iField=1:length(fields)
          field = fields{iField}; % get field name
          x = s(iItem).(field);
          if (iscell(x) && all(cellfun(@isstruct,x))) % it's cells of structs
            try                           % this operation fails sometimes
              s(iItem).(field) = [x{:}];  % converted to arrays of structs
            catch
              if (Pref.NoCells)
                s(iItem).(field) = forceCell2Struct(x);
              end
            end % end catch
          end
        end
      end
    end
end

%% =======================================================================
%  === forceCell2Struct Function =========================================
%  =======================================================================
function s = forceCell2Struct(x)
% Convert cell array of structs, where not all of structs have the same
% fields, to a single array of structs

%% Convert 1D cell array of structs to 2D cell array, where each row
% represents item in original array and each column corresponds to a unique
% field name. Array "AllFields" store fieldnames for each column
    AllFields = fieldnames(x{1});     % get field names of the first struct
    CellMat = cell(length(x), length(AllFields));
    for iItem=1:length(x)
      fields = fieldnames(x{iItem});  % get field names of the next struct
      for iField=1:length(fields)     % inspect all fieldnames and find those
        field = fields{iField};       % get field name
        col = find(strcmp(field,AllFields),1);
        if isempty(col)               % no column for such fieldname yet
          AllFields = [AllFields; field];
          col = length(AllFields);    % create a new column for it
        end
        CellMat{iItem,col} = x{iItem}.(field); % store rearanged data
      end
    end
    %% Convert 2D cell array to array of structs
    s = cell2struct(CellMat, AllFields, 2);
end

%% =======================================================================
%  === str2var Function ==================================================
%  =======================================================================
function val=str2var(str)
% Can this string be converted to a number? if so than do it.
    val = str;
    if (numel(str)==0), return; end
    digits = '[Inf,NaN,pi,\t,\n,\d,\+,\-,\*,\.,e,i, ,E,I,\[,\],\;,\,]';
    s = regexprep(str, digits, ''); % remove all the digits and other allowed characters
    if (~all(~isempty(s)))          % if nothing left than this is probably a number
      str(strcmp(str,'\n')) = ';';  % parse data tables into 2D arrays, if any
    %   try                           % try to convert to a date, like 2007-12-05
    %     datenum(str);               % if successful than leave it alone
    %   catch                         % if this is not a date than ...
        num = str2num(str);         % ... try converting to a number
        if(isnumeric(num) && numel(num)>0), val=num; end % if a number than save
    %   end
    end
end

%% =======================================================================
%  === str2varName Function ==============================================
%  =======================================================================
function str = str2varName(str)
% convert a sting to a valid matlab variable name
    str = regexprep(str,':','_COLON_', 'once', 'ignorecase');
    str = regexprep(str,'-','_DASH_'  ,'once', 'ignorecase');
    if (~isvarname(str)), str = matlab.lang.makeValidName(str); end
end

%% =======================================================================
%  === NodeName Function =================================================
%  =======================================================================
function [Name LeafNode] = NodeName(node)
% get node name and make sure it is a valid variable name in Matlab.
% also get node type:
%   LeafNode=0 - normal element node,
%   LeafNode=1 - text node
%   LeafNode=2 - supported non-text leaf node,
%   LeafNode=3 - supported processing instructions leaf node,
%   LeafNode=-1 - unsupported non-text leaf node
    switch (node.getNodeType)
      case node.ELEMENT_NODE
        Name = char(node.getNodeName);% capture name of the node
        Name = str2varName(Name);     % if Name is not a good variable name - fix it
        LeafNode = 0;
      case node.TEXT_NODE
        Name = 'CONTENT';
        LeafNode = 1;
      case node.COMMENT_NODE
        Name = 'COMMENT';
        LeafNode = 2;
      case node.CDATA_SECTION_NODE
        Name = 'CDATA_SECTION';
        LeafNode = 2;
      case node.DOCUMENT_TYPE_NODE
        Name = 'DOCUMENT_TYPE';
        LeafNode = 2;
      case node.PROCESSING_INSTRUCTION_NODE
        Name = 'PROCESSING_INSTRUCTION';
        LeafNode = 3;
      otherwise
        NodeType = {'ELEMENT','ATTRIBUTE','TEXT','CDATA_SECTION', ...
          'ENTITY_REFERENCE', 'ENTITY', 'PROCESSING_INSTRUCTION', 'COMMENT',...
          'DOCUMENT', 'DOCUMENT_TYPE', 'DOCUMENT_FRAGMENT', 'NOTATION'};
        Name = char(node.getNodeName);% capture name of the node
        warning('xml_io_tools:read:unkNode', ...
          'Unknown node type encountered: %s_NODE (%s)', NodeType{node.getNodeType}, Name);
        LeafNode = -1;
    end
end

%% =======================================================================
%  === expand_tree Function =================================================
%  =======================================================================
function otree = expand_tree(itree,Pref)
    if isfield(itree,'local') % locals used
        assert(Pref.ReadAttr,'XML Inclusions (XInclude) requires ReadAttr = true');
        if isOctave
            otree = readxml(which(itree.xi_COLON_include.ATTRIBUTE.href));
        else
            rootName = fieldnames(itree);
            otree = expand_tree(itree.(rootName{1}),Pref);
        end
        otree = mergeStructs(otree,itree.local,Pref);
    else
        otree = itree;
    end
end

%% =======================================================================
%  === mergeStructs Function =================================================
%  =======================================================================
function res = mergeStructs(x,y,Pref)
% From: http://stackoverflow.com/a/6271161
    if isstruct(x) && isstruct(y)
        res = x;

        if numel(res) > 1 || numel(y) > 1 % orig is array
            for yitem = 1:numel(y) % for each new item
                % look for corresponding item (i.e. any matching)
                if ~isfield(res,Pref.ItemID) || ~isfield(y,Pref.ItemID), error('ARRAY ERROR: Field %s as specified in Pref.ItemID not found.', Pref.ItemID); end
                if isstruct(res(1).(Pref.ItemID)) % attributes
                    xIDs = arrayfun(@(item) item.(Pref.ItemID).CONTENT, res, 'UniformOutput', false);
                    yID = y(yitem).(Pref.ItemID).CONTENT;
                else
                    xIDs = {res.(Pref.ItemID)};
                end
                itemmatch = strcmp(xIDs,yID);
                if any(itemmatch) % update
                    res(itemmatch) = mergeStructs(res(itemmatch),y(yitem),Pref);
                else % append - handle partial structures
                    structInit = reshape(cat(2,fieldnames(res),cell(numel(fieldnames(res)),1))',1,[]);
                    newstruct = struct(structInit{:});
                    for f = fieldnames(y(yitem))', newstruct.(f{1}) = y(yitem).(f{1}); end
                    res(end+1) = newstruct;
                end
            end
            return
        end

        names = fieldnames(y);
        for fnum = 1:numel(names)
            if isfield(x,names{fnum})
                res.(names{fnum}) = mergeStructs(x.(names{fnum}),[y.(names{fnum})],Pref);
            else
                res.(names{fnum}) = y.(names{fnum});
            end
        end
    else
        res = y;
    end
end
