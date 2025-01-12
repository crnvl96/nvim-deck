local notify = require('deck.notify')
local System = require('deck.kit.System')

--[=[@doc
  category = "source"
  name = "grep"
  desc = "Grep files under specified root directory. (required `ripgrep`)"
  example = """
    deck.start(require('deck.builtin.source.grep')({
      root_dir = vim.fn.getcwd(),
      pattern = vim.fn.input('grep: '),
      ignore_globs = { '**/node_modules/', '**/.git/' },
    }))
  """

  [[options]]
  name = "root_dir"
  type = "string"
  desc = "Target root directory."

  [[options]]
  name = "pattern"
  type = "string?"
  desc = "Grep pattern. If you omit this option, you must set `dynamic` option to true."

  [[options]]
  name = "dynamic"
  type = "boolean?"
  default = "false"
  desc = "If true, use dynamic pattern. If you set this option to false, you must set `pattern` option."

  [[options]]
  name = "ignore_globs"
  type = "string[]?"
  default = "[]"
  desc = "Ignore glob patterns."
]=]
---@class deck.builtin.source.grep.Option
---@field root_dir string
---@field pattern? string
---@field dynamic? boolean
---@field ignore_globs? string[]
---@param option deck.builtin.source.grep.Option
return function(option)
  if type(option.dynamic) == 'boolean' and not option.dynamic then
    error('dynamic option must be true. alternatively, you can specify `option.pattern` instead.')
  elseif not option.dynamic and (type(option.pattern) ~= 'string' or #option.pattern == 0) then
    error('pattern option must be a non-empty string.')
  end

  ---@type deck.Source
  return {
    name = 'grep',
    dynamic = option.dynamic,
    execute = function(ctx)
      local query = option.dynamic and ctx.get_query() or option.pattern or ''
      if query == '' then
        return ctx.done()
      end

      local command = {
        'rg',
        '--ignore-case',
        '--column',
        '--line-number',
        '--hidden',
        '--sort',
        'path',
      }

      if option.ignore_globs then
        for _, glob in ipairs(option.ignore_globs) do
          table.insert(command, '--glob')
          table.insert(command, '!' .. glob)
        end
      end

      table.insert(command, '-e')
      table.insert(command, query)

      ctx.on_abort(System.spawn(command, {
        cwd = option.root_dir,
        env = {},
        buffering = System.LineBuffering.new({
          ignore_empty = true,
        }),
        on_stdout = function(text)
          local filename = text:match('^[^:]+')
          local lnum = tonumber(text:match(':(%d+):'))
          local col = tonumber(text:match(':%d+:(%d+):'))
          local match = text:match(':%d+:%d+:(.*)$')
          if filename and match then
            ctx.item({
              display_text = {
                { ('%s (%s:%s): '):format(filename, lnum, col) },
                { match, 'Comment' },
              },
              data = {
                filename = vim.fs.joinpath(option.root_dir, filename),
                lnum = lnum,
                col = col,
              },
            })
          end
        end,
        on_stderr = function(text)
          notify.show({
            { { ('[grep: stderr] %s'):format(text), 'ErrorMsg' } },
          })
        end,
        on_exit = function()
          ctx.done()
        end,
      }))
    end,
    actions = {
      require('deck').alias_action('default', 'open'),
    },
  }
end
