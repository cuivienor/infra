# Opencode Plugins

This directory (`.config/opencode/plugins/`) contains custom plugins for Opencode to extend and customize its behavior.

## Available Plugins

### remove-unsupported-params.ts

**Purpose**: Fixes compatibility issues with Shopify's internal AI proxy when using GPT-5 models.

**What it does**:
- Removes the unsupported `textVerbosity` parameter
- Remaps `max_completion_tokens` to `max_tokens` for GPT-5 compatibility
- Only applies to Shopify provider with GPT-5 models

**When it runs**: Before chat parameters are sent to the provider (using the `chat.params` hook)

## Plugin Development

Plugins in Opencode follow these best practices:

1. **TypeScript Types**: Always import and use the `Plugin` type from `@opencode-ai/plugin`
2. **Selective Application**: Check provider and model IDs before applying transformations
3. **Clean Mutations**: Use `undefined` to remove parameters rather than `delete`
4. **Documentation**: Include JSDoc comments explaining the plugin's purpose
5. **Debugging**: Optional debug logging controlled by environment variables

## Adding New Plugins

1. Create a new TypeScript or JavaScript file in this directory
2. Export a named function that follows the Plugin interface
3. The plugin will be automatically loaded when Opencode starts
4. Restart Opencode to load the new plugin

## Available Hooks

- `chat.params`: Modify chat parameters before sending to provider
- `chat.response`: Process responses from the provider
- `chat.error`: Handle errors from the provider
- `tool.execute`: Intercept tool executions
- `agent.init`: Initialize agent-specific behavior

For more information, see the [Opencode Plugins Documentation](https://opencode.ai/docs/plugins).
