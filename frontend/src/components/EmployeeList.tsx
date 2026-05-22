import React, { useEffect, useState } from "react";
import { Employee } from "../types/employee";
import "./EmployeeList.css";

// In production the CI pipeline sets REACT_APP_API_URL to the Function App URL
// from terraform output before running `npm run build`.
const API_BASE = process.env.REACT_APP_API_URL ?? "/api";

export default function EmployeeList() {
  const [employees, setEmployees] = useState<Employee[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [search, setSearch] = useState("");

  useEffect(() => {
    fetch(`${API_BASE}/employees`)
      .then((res) => {
        if (!res.ok) throw new Error(`HTTP ${res.status} — ${res.statusText}`);
        return res.json() as Promise<Employee[]>;
      })
      .then((data) => {
        setEmployees(data);
        setLoading(false);
      })
      .catch((err: Error) => {
        setError(err.message);
        setLoading(false);
      });
  }, []);

  const filtered = employees.filter(
    (e) =>
      e.name.toLowerCase().includes(search.toLowerCase()) ||
      e.department.toLowerCase().includes(search.toLowerCase())
  );

  if (loading) {
    return (
      <div className="state-box">
        <div className="spinner" aria-label="Loading" role="status" />
        <p>Loading employees…</p>
      </div>
    );
  }

  if (error) {
    return (
      <div className="state-box error">
        <p>⚠ Failed to load employees</p>
        <p className="error-detail">{error}</p>
      </div>
    );
  }

  return (
    <section className="employee-section" aria-label="Employee directory">
      <div className="controls">
        <input
          type="search"
          placeholder="Search by name or department…"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          className="search-input"
          aria-label="Search employees"
        />
        <span className="count" aria-live="polite">
          {filtered.length} {filtered.length === 1 ? "employee" : "employees"}
        </span>
      </div>

      <div className="table-wrapper" role="region" aria-label="Employee list">
        <table className="employee-table">
          <thead>
            <tr>
              <th scope="col">#</th>
              <th scope="col">Name</th>
              <th scope="col">Department</th>
            </tr>
          </thead>
          <tbody>
            {filtered.length === 0 ? (
              <tr>
                <td colSpan={3} className="empty">
                  No employees match your search.
                </td>
              </tr>
            ) : (
              filtered.map((emp, i) => (
                <tr key={emp.id}>
                  <td className="row-num">{i + 1}</td>
                  <td className="emp-name">{emp.name}</td>
                  <td>
                    <span className="dept-badge">{emp.department}</span>
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>
    </section>
  );
}
