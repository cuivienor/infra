-- Diagnostics utilities for viewing all diagnostics with source information

return {
  "neovim/nvim-lspconfig",
  config = function()
    -- Command to show all diagnostics with detailed source info
    vim.api.nvim_create_user_command("DiagnosticsInfo", function()
      local diagnostics = vim.diagnostic.get()
      
      if #diagnostics == 0 then
        vim.notify("No diagnostics found", vim.log.levels.INFO)
        return
      end
      
      local lines = { "All Diagnostics (" .. #diagnostics .. " total):", "" }
      local by_source = {}
      
      -- Group diagnostics by source
      for _, diag in ipairs(diagnostics) do
        local source = diag.source or "Unknown"
        if not by_source[source] then
          by_source[source] = {}
        end
        table.insert(by_source[source], diag)
      end
      
      -- Display grouped by source
      for source, diags in pairs(by_source) do
        table.insert(lines, string.format("📌 %s (%d):", source, #diags))
        table.insert(lines, string.rep("-", 40))
        
        for _, diag in ipairs(diags) do
          local bufnr = diag.bufnr
          local filename = vim.api.nvim_buf_get_name(bufnr)
          local short_name = vim.fn.fnamemodify(filename, ":~:.")
          local severity = vim.diagnostic.severity[diag.severity]
          
          table.insert(lines, string.format(
            "  [%s] %s:%d:%d",
            severity,
            short_name,
            diag.lnum + 1,
            diag.col + 1
          ))
          
          -- Wrap message text
          local message = diag.message:gsub("\n", " ")
          if #message > 60 then
            message = message:sub(1, 60) .. "..."
          end
          table.insert(lines, "    " .. message)
          
          if diag.code then
            table.insert(lines, "    Code: " .. tostring(diag.code))
          end
          table.insert(lines, "")
        end
      end
      
      -- Display in a floating window
      local buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
      vim.api.nvim_buf_set_option(buf, 'modifiable', false)
      
      local width = math.min(80, vim.o.columns - 4)
      local height = math.min(#lines, vim.o.lines - 4)
      
      vim.api.nvim_open_win(buf, true, {
        relative = 'editor',
        width = width,
        height = height,
        col = (vim.o.columns - width) / 2,
        row = (vim.o.lines - height) / 2,
        style = 'minimal',
        border = 'rounded',
        title = ' Diagnostics Info ',
        title_pos = 'center',
      })
      
      -- Add keybindings to close
      vim.api.nvim_buf_set_keymap(buf, 'n', 'q', ':close<CR>', { noremap = true, silent = true })
      vim.api.nvim_buf_set_keymap(buf, 'n', '<Esc>', ':close<CR>', { noremap = true, silent = true })
    end, { desc = "Show all diagnostics grouped by source" })
    
    -- Command to show diagnostics summary
    vim.api.nvim_create_user_command("DiagnosticsSummary", function()
      local diagnostics = vim.diagnostic.get()
      local by_source = {}
      local by_severity = {
        [vim.diagnostic.severity.ERROR] = 0,
        [vim.diagnostic.severity.WARN] = 0,
        [vim.diagnostic.severity.INFO] = 0,
        [vim.diagnostic.severity.HINT] = 0,
      }
      
      for _, diag in ipairs(diagnostics) do
        local source = diag.source or "Unknown"
        by_source[source] = (by_source[source] or 0) + 1
        by_severity[diag.severity] = by_severity[diag.severity] + 1
      end
      
      local lines = { "Diagnostics Summary", "" }
      
      table.insert(lines, "By Severity:")
      table.insert(lines, string.format("  Errors: %d", by_severity[vim.diagnostic.severity.ERROR]))
      table.insert(lines, string.format("  Warnings: %d", by_severity[vim.diagnostic.severity.WARN]))
      table.insert(lines, string.format("  Info: %d", by_severity[vim.diagnostic.severity.INFO]))
      table.insert(lines, string.format("  Hints: %d", by_severity[vim.diagnostic.severity.HINT]))
      table.insert(lines, "")
      
      table.insert(lines, "By Source:")
      for source, count in pairs(by_source) do
        table.insert(lines, string.format("  %s: %d", source, count))
      end
      
      vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
    end, { desc = "Show diagnostics summary by source and severity" })
    
    -- Keybindings
    vim.keymap.set('n', '<leader>da', ':DiagnosticsInfo<CR>', { desc = '[D]iagnostics [A]ll with sources' })
    vim.keymap.set('n', '<leader>ds', ':DiagnosticsSummary<CR>', { desc = '[D]iagnostics [S]ummary' })
  end
}