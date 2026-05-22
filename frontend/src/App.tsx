import React from "react";
import EmployeeList from "./components/EmployeeList";
import "./App.css";

export default function App() {
  return (
    <div className="app">
      <header className="app-header">
        <div className="header-inner">
          <h1>Employee Directory</h1>
          <p>Backed by Azure Cosmos DB · Secured with Managed Identity</p>
        </div>
      </header>
      <main className="app-main">
        <EmployeeList />
      </main>
    </div>
  );
}
