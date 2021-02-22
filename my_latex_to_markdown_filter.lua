local system = require 'pandoc.system'
local string = require 'string'


local block_filter = {
  RawBlock = function (el)
    return RawBlock(el)
  end
}
local inline_filter = {
  RawInline = function (el)
    return RawInline(el)
  end
}

function dump(o) --- for printing a table
   if type(o) == 'table' then
      local s = '{ '
      for k,v in pairs(o) do
         if type(k) ~= 'number' then k = '"'..k..'"' end
         s = s .. '['..k..'] = ' .. dump(v) .. ','
      end
      return s .. '} '
   else
      return tostring(o)
   end
end

local function TableConcat(t1,t2)
    for i=1,#t2 do
        t1[#t1+1] = t2[i]  --corrected bug. if t1[#t1+i] is used, indices will be skipped
    end
    return t1
end

local function strip_environment(el,env)
  local el_text = el.text:match("\\begin{" .. env .. "}(.-)\\end{" .. env .. "}")
  local el_read = pandoc.read(el_text,'latex+raw_tex').blocks
  return el_read
end

local function strip_environment_opts(el,env)
  local el_text = el.text:match("\\begin{" .. env .. "}[.-](.-)\\end{" .. env .. "}")
  local el_read = pandoc.read(el_text,'latex+raw_tex').blocks
  return el_read
end

local function starts_with(start, str)
  return str:sub(1, #start) == start
end

local function keyworder(element)
  local main_text = element.text:match("{(.-)}")
  return pandoc.Span(main_text,{'keyword'})
end

local function referencer(element)
  local main_text = element.text:match("{(.-)}")
  return pandoc.RawInline('markdown',"[@" .. main_text .. "]")
end

local function urler(element)
  local main_text = element.text:match("{(.-)}")
  return pandoc.Span(
      pandoc.RawInline('markdown',"[" .. main_text .. "](" .. main_text .. ")"),
      {'myurl'}
    )
end

local function keyer(element)
  local main_text = element.text:match("{(.-)}")
  return pandoc.Span(
      pandoc.Str(main_text),
      {'key'}
    )
end

local function mpyer(element)
  local main_text = element.text:match("{(.-)}")
  return pandoc.Code(main_text)
end

local function exa_get_problem(element,environment)
  local main_text = element.text:match("^\\begin{" .. environment .. "}(.-)\\tcblower")
  return pandoc.Div(pandoc.Para(main_text),{'exa_problem'})
end

local function exa_get_solution(element,environment)
  local main_text = element.text:match("\\tcblower(.-)\\end{" .. environment .. "}")
  return pandoc.Div(pandoc.Para(main_text),{'exa_solution'})
end

local function replace_myexample(el)
  problem = exa_get_problem(el,'myexample')
  solution = exa_get_solution(el,'myexample')
  return {problem,solution}
end

local function Definition_get_name(element)
  local main_text = element.text:match("\\begin{Definition}{(.-)}")
  return main_text
end

local function Definition_get_ref(element)
  local main_text = element.text:match("\\begin{Definition}{.-}{(.-)}")
  return main_text
end

local function Definition_get(element)
  local main_text = element.text:match("\\begin{Definition}{.-}{.-}(.-)\\end{Definition}")
  return pandoc.Str(main_text)
end

local function replace_Definition(el)
  local name = Definition_get_name(el)
  local ref = Definition_get_ref(el)
  local definition = Definition_get(el)
  return pandoc.Div(pandoc.Para(definition),{ref,{name}})
end

local function infobox_get_name(element)
  local main_text = element.text:match("\\begin{infobox}%[(.-)%]")
  return main_text
end

local function infobox_get_ref(element)
  local main_text = element.text:match("\\label{(.-)}")
  return main_text
end

local function infobox_get(element)
  local main_text = element.text:match("\\begin{infobox}%[.-%](.-)\\end{infobox}")
  return main_text
end

local function replace_infobox(el)
  local name = infobox_get_name(el)
  local ref = infobox_get_ref(el)
  local contents = pandoc.Div(
      pandoc.read(infobox_get(el),'latex+raw_tex').blocks,
      {'infobox_contents'}
    )
  return pandoc.Div(
    {
      pandoc.Div(pandoc.Para(name),{'infobox_name'}),
      contents
    },
    {ref or 'labelme',{'infobox'}}
  )
end

local function replace_exercise(el)
  local id1 = el.text:match("ID=(.-),")
  local id2 = el.text:match("ID=(.-)]")
  if id1 == nil and id2 == nil then
    id = "IDME"
  elseif id1 == nil then
    id = id2
  elseif id2 == nil then
    id = id1
  else
    id = "IDME"
  end
  if el.text:match("\\begin{exercise}%[") == nil then
    local el_s = strip_environment(el,'exercise')
  else
    local el_s = strip_environment_opts(el,'exercise')
  end --- this sometimes gives nil ... it's in the pandoc.read of strip_environment but I can't find the bug .. that's why the "or" below
  local contents = pandoc.Div(
      el_s or pandoc.RawBlock('latex',el.text:match("\\begin{exercise}(.-)\\end{exercise}")),
      {'exercise_contents'}
    )
  return pandoc.Div(
    {
      pandoc.Div(pandoc.Para('Exercise'),{'exercise_title'}),
      contents
    },
    {id,{'exercise'}}
  )
end

local function replace_solution(el)
  local el_s = strip_environment(el,'solution')
  local contents = pandoc.Div(
      el_s or pandoc.Para('solution did not convert'),
      {'solution_contents'}
    )
  return pandoc.Div(
    {
      pandoc.Div(pandoc.Para('Solution'),{'solution_title'}),
      contents
    },
    {'labelme',{'solution'}}
  )
end

local function replace_subfile(el)
  local filename = el.text:match("\\subfile{(.-)}")
  local f = assert(io.open(filename .. ".tex", "rb"))
  local content = f:read("*all")
  f:close()
  local tex_contents = pandoc.Div(
    pandoc.read(content,'latex+raw_tex').blocks
  )
  return pandoc.walk_block(
    tex_contents,
    block_filter
  ).content
end

local function replace_input(el)
  local filename = el.text:match("\\input{(.-)}")
  local f = assert(io.open(filename .. ".tex", "rb"))
  local content = f:read("*all")
  f:close()
  local tex_contents = pandoc.Div(
    pandoc.read(content,'latex+raw_tex').blocks
  )
  return pandoc.walk_block(
    tex_contents,
    block_filter
  ).content
end

local function replace_resource(el)
  local title = pandoc.walk_inline(
    pandoc.Str(
      el.text:match("\\resource{.-}{(.-)}")
    ),
    inline_filter
  )
  local ref = el.text:match("\\resource{.-}{.-}{(.-)}")
  return pandoc.Header(2,title,{ref or 'labelme',{'resource'}})
end

local function replace_todolist(el)
  local el_text_itemize = el.text:gsub("{todolist}","{itemize}")
  local el_text_itemize = el_text_itemize:gsub("\\item[.-]","\\item")
  local el_read = pandoc.read(el_text_itemize,'latex+raw_tex').blocks
  return el_read
end

function RawInline(el)
  if starts_with('\\keyword', el.text) then
    return keyworder(el)
  elseif starts_with('\\ref', el.text) or starts_with('\\cref', el.text) or starts_with('\\autoref', el.text) then
    return referencer(el)
  elseif starts_with('\\myurl', el.text) then
    return urler(el)
  elseif starts_with('\\mpy', el.text) or starts_with('\\mc', el.text) or starts_with('\\mb', el.text) then
    return mpyer(el)
  elseif starts_with('\\path', el.text) then
    return mpyer(el)
  elseif starts_with('\\keys', el.text) then
    return keyer(el)
  else
    return el
  end
end

function RawBlock(el)
  if starts_with('\\begin{myexample}', el.text) then
    local converted = replace_myexample(el)
    return pandoc.Div(converted,{'example'})
  elseif starts_with('\\begin{Definition}', el.text) then
    return replace_Definition(el)
  elseif starts_with('\\begin{infobox}', el.text) then
    return replace_infobox(el)
  elseif starts_with('\\begin{exercise}', el.text) then
    return replace_exercise(el)
  elseif starts_with('\\begin{solution}', el.text) then
    return replace_solution(el)
  elseif starts_with('\\clearpage', el.text) then
    return {}
  elseif starts_with('\\centering', el.text) then
    return {}
  elseif starts_with('\\subfile', el.text) then
    return replace_subfile(el)
  elseif starts_with('\\input', el.text) then
    return replace_input(el)
  elseif starts_with('\\resource', el.text) then
    return replace_resource(el)
  elseif starts_with('\\begin{todolist}', el.text) then
    return replace_todolist(el)
  elseif starts_with('\\begin{subequations}', el.text) then
    return strip_environment(el,'subequations')
  else
    return el
  end
end