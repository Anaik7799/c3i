import cepaf_gleam/mcp/protocol.{type ToolDefinition, ToolDefinition}
import gleam/json

pub fn get_tool_definitions() -> List(ToolDefinition) {
  [
    ToolDefinition(
      name: "planning_query",
      description: "Read PROJECT_TODOLIST.md and return its content",
      input_schema: json.object([
        #("type", json.string("object")),
        #("properties", json.object([])),
      ]),
    ),
    ToolDefinition(
      name: "knowledge_search",
      description: "Search the knowledge base for relevant information",
      input_schema: json.object([
        #("type", json.string("object")),
        #(
          "properties",
          json.object([
            #(
              "query",
              json.object([
                #("type", json.string("string")),
                #("description", json.string("Search query")),
              ]),
            ),
          ]),
        ),
        #("required", json.array([json.string("query")], of: fn(x) { x })),
      ]),
    ),
    ToolDefinition(
      name: "verification_run",
      description: "Run gleam check and return the result",
      input_schema: json.object([
        #("type", json.string("object")),
        #("properties", json.object([])),
      ]),
    ),
    ToolDefinition(
      name: "read_file",
      description: "Read content from a file",
      input_schema: json.object([
        #("type", json.string("object")),
        #(
          "properties",
          json.object([
            #(
              "path",
              json.object([
                #("type", json.string("string")),
                #("description", json.string("Path to the file")),
              ]),
            ),
          ]),
        ),
        #("required", json.array([json.string("path")], of: fn(x) { x })),
      ]),
    ),
    ToolDefinition(
      name: "todo_status",
      description: "Parse PROJECT_TODOLIST.md and return task counts by status",
      input_schema: json.object([
        #("type", json.string("object")),
        #("properties", json.object([])),
      ]),
    ),
  ]
}
