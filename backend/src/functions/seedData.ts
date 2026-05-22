import { app, HttpRequest, HttpResponseInit, InvocationContext } from "@azure/functions";
import { CosmosClient } from "@azure/cosmos";
import { DefaultAzureCredential } from "@azure/identity";

const EMPLOYEES = [
  { id: "1", name: "Alice Johnson",  department: "Engineering"  },
  { id: "2", name: "Bob Smith",      department: "Marketing"    },
  { id: "3", name: "Carol White",    department: "HR"           },
  { id: "4", name: "David Brown",    department: "Finance"      },
  { id: "5", name: "Eve Davis",      department: "Engineering"  },
  { id: "6", name: "Frank Wilson",   department: "Operations"   },
  { id: "7", name: "Grace Lee",      department: "Product"      },
  { id: "8", name: "Henry Zhang",    department: "Sales"        },
];

export async function seedData(
  _request: HttpRequest,
  context: InvocationContext
): Promise<HttpResponseInit> {
  context.log("seedData triggered");

  const endpoint = process.env.COSMOS_ENDPOINT!;
  const databaseName = process.env.COSMOS_DATABASE_NAME!;
  const containerName = process.env.COSMOS_CONTAINER_NAME!;

  const credential = new DefaultAzureCredential();
  const client = new CosmosClient({ endpoint, aadCredentials: credential });
  const container = client.database(databaseName).container(containerName);

  try {
    await Promise.all(EMPLOYEES.map((emp) => container.items.upsert(emp)));
    return {
      status: 200,
      jsonBody: { message: `Seeded ${EMPLOYEES.length} employees successfully` },
    };
  } catch (err) {
    context.error("Seed failed:", err);
    return { status: 500, jsonBody: { error: String(err) } };
  }
}

app.http("seedData", {
  methods: ["POST"],
  authLevel: "function", // Requires a function key — not exposed as a public endpoint
  route: "seed",
  handler: seedData,
});
