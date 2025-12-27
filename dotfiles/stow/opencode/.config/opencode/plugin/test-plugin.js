/**
 * Test plugin to verify plugin loading
 * This can be removed once you confirm plugins are loading correctly
 */
export const TestPlugin = async ({ project, client, $, directory, worktree }) => {
  console.log("[TestPlugin] ✅ Plugins are loading correctly from .config/opencode/plugins/");
  console.log("[TestPlugin] Directory:", directory);

  return {
    // Log when a session starts
    event: async ({ event }) => {
      if (event.type === "session.start") {
        console.log("[TestPlugin] Session started - plugins are active!");
      }
    }
  };
};
