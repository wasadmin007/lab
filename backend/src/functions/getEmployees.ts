import { app, HttpRequest, HttpResponseInit, InvocationContext } from "@azure/functions";
import { CosmosClient } from "@azure/cosmos";
import { DefaultAzureCredential } from "@azure/identity";

const endpoint = process.env.COSMOS_ENDPOINT!;
const databaseName = process.env.COSMOS_DATABASE_NAME!;
const containerName = process.env.COSMOS_CONTAINER_NAME!;

// DefaultAzureCredential resolves to the Function App's system-assigned managed
// identity when running in Azure, and to `az login` / VS Code credentials locally.
// No connection strings or keys are used anywhere in this code.
const credential = new DefaultAzureCredential();
const cosmosClient = new CosmosClient({ endpoint, aadCredentials: credential });

export async function getEmployees(
  _request: HttpRequest,
  context: InvocationContext
): Promise<HttpResponseInit> {
  context.log("getEmployees triggered");

  try {
    const { resources } = await cosmosClient
      .database(databaseName)
      .container(containerName)
      .items.query<{ id: string; name: string; department: string }>(
        "SELECT c.id, c.name, c.department FROM c ORDER BY c.name"
      )
      .fetchAll();

    return {
      status: 200,
      jsonBody: resources,
      headers: { "Content-Type": "application/json" },
    };
  } catch (err) {
    context.error("Failed to query Cosmos DB:", err);
    return {
      status: 500,
      jsonBody: { error: "Internal server error" },
    };
  }
}

app.http("getEmployees", {
  methods: ["GET"],
  authLevel: "anonymous",
  route: "employees",
  handler: getEmployees,
});
