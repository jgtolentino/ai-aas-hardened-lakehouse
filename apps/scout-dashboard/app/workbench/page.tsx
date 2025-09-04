export default function WorkbenchPage() {
  return (
    <div className="container mx-auto px-4 py-8">
      <h1 className="text-4xl font-bold mb-8">Neural DB Workbench</h1>
      <div className="grid gap-6">
        <div className="rounded-lg border bg-card p-6">
          <h2 className="text-2xl font-semibold mb-4">Vector Collections</h2>
          <p className="text-muted-foreground">Manage and query semantic embeddings</p>
        </div>
        <div className="rounded-lg border bg-card p-6">
          <h2 className="text-2xl font-semibold mb-4">Semantic Search</h2>
          <p className="text-muted-foreground">Neural-powered content discovery</p>
        </div>
        <div className="rounded-lg border bg-card p-6">
          <h2 className="text-2xl font-semibold mb-4">Knowledge Graph</h2>
          <p className="text-muted-foreground">Entity relationships and insights</p>
        </div>
      </div>
    </div>
  );
}