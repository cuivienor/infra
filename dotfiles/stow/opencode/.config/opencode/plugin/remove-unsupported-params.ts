import type { Plugin } from "@opencode-ai/plugin"
        export const RemoveUnsupportedParams: Plugin = async () => {
          return {
            async "chat.params"({ provider, model }, output) {
              if (provider.info.id.includes("shopify") && model.id.includes("gpt-5")) {
                output.options["textVerbosity"] = undefined
                output.options["max_completion_tokens"] = output.options["max_tokens"]
                output.options["max_tokens"] = undefined
              }
            }
          }
        }
