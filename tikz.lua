local system = require 'pandoc.system'

local tikz_doc_template = [[
\documentclass{standalone}
\usepackage{bm}
\usepackage[obeyspaces]{xcolor}
\definecolor{lightgray}{gray}{0.9}
\definecolor{mylightgrey}{cmyk}{0,0,0,0.1}
\definecolor{myfunblue}{cmyk}{1,.2,.1,.2}
\definecolor{myfungrey}{cmyk}{.05,.05,.01,.01}
\definecolor{mygreen}{cmyk}{1,0,1,0.39}
\definecolor{mydarkgrey}{cmyk}{.05,.05,.05,.85}
\usepackage{tikz}
\usepackage{etoolbox}
\usepackage{pgfplots}
\usetikzlibrary{arrows}
\usetikzlibrary{arrows.meta}
\pgfplotsset{compat=1.9}
\usetikzlibrary{backgrounds}
\usepackage{currfile}
\usetikzlibrary{matrix}
\usepgfplotslibrary{groupplots}
\usetikzlibrary{calc,patterns,decorations.pathmorphing,decorations.markings}
\begin{document}
\nopagecolor
%s
\end{document}
]]

local function tikz2image(src, filetype, outfile)
  system.with_temporary_directory('tikz2image', function (tmpdir)
    system.with_working_directory(tmpdir, function()
      local f = io.open('tikz.tex', 'w')
      f:write(tikz_doc_template:format(src))
      f:close()
      os.execute('pdflatex tikz.tex')
      if filetype == 'pdf' then
        os.rename('tikz.pdf', outfile)
      else
        os.execute('pdf2svg tikz.pdf ' .. outfile)
      end
    end)
  end)
end

extension_for = {
  html = 'svg',
  html4 = 'svg',
  html5 = 'svg',
  latex = 'pdf',
  beamer = 'pdf' }

local function file_exists(name)
  local f = io.open(name, 'r')
  if f ~= nil then
    io.close(f)
    return true
  else
    return false
  end
end

local function starts_with(start, str)
  return str:sub(1, #start) == start
end


function RawBlock(el)
  if starts_with('\\begin{tikzpicture}', el.text) then
    local filetype = extension_for[FORMAT] or 'svg'
    local fname = system.get_working_directory() .. '/' ..
        pandoc.sha1(el.text) .. '.' .. filetype
    if not file_exists(fname) then
      tikz2image(el.text, filetype, fname)
    end
    return pandoc.Para({pandoc.Image({}, fname)})
  else
   return el
  end
end