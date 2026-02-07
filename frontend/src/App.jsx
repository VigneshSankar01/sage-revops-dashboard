import { useState, useEffect } from 'react'
import './App.css'

const API_URL = 'https://tm4o7kgf22.execute-api.us-east-1.amazonaws.com/prod/api'

function App() {
  const [regionData, setRegionData] = useState([])
  const [productData, setProductData] = useState([])
  const [lastMonthData, setLastMonthData] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)

  useEffect(() => {
    fetchData()
  }, [])

  const fetchData = async () => {
    setLoading(true)
    setError(null)

    try {
      // Fetch region data (from S3 - cached)
      const regionResponse = await fetch(`${API_URL}/pipeline/by-region`)
      const regionJson = await regionResponse.json()
      
      // Fetch product data (from S3 - cached)
      const productResponse = await fetch(`${API_URL}/pipeline/by-product`)
      const productJson = await productResponse.json()

      // Fetch REAL-TIME last month data (from Snowflake - live!)
      const lastMonthResponse = await fetch(`${API_URL}/sales/last-month`)
      const lastMonthJson = await lastMonthResponse.json()

      setRegionData(regionJson.data || [])
      setProductData(productJson.data || [])
      setLastMonthData(lastMonthJson.data || [])
    } catch (err) {
      setError(err.message)
    } finally {
      setLoading(false)
    }
  }

  const formatCurrency = (value) => {
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: 'USD',
      minimumFractionDigits: 0,
      maximumFractionDigits: 0,
    }).format(value)
  }

  if (loading) {
    return (
      <div className="container">
        <div className="loading">Loading pipeline data...</div>
      </div>
    )
  }

  if (error) {
    return (
      <div className="container">
        <div className="error">Error: {error}</div>
      </div>
    )
  }

  return (
    <div className="container">
      <header className="header">
        <h1>Sage RevOps Dashboard</h1>
        <p>Pipeline Analytics & Insights</p>
      </header>

      <div className="dashboard">
        {/* Pipeline by Region */}
        <section className="card">
          <h2>Pipeline by Region</h2>
          <div className="table-container">
            <table>
              <thead>
                <tr>
                  <th>Region</th>
                  <th>Total Amount</th>
                  <th>Deal Count</th>
                  <th>Avg Deal Size</th>
                  <th>Closed</th>
                  <th>Open</th>
                </tr>
              </thead>
              <tbody>
                {regionData.map((row, idx) => (
                  <tr key={idx}>
                    <td className="region-name">{row.region}</td>
                    <td className="currency">{formatCurrency(row.total_amount)}</td>
                    <td className="center">{row.deal_count}</td>
                    <td className="currency">{formatCurrency(row.avg_deal_size)}</td>
                    <td className="currency success">{formatCurrency(row.closed_amount)}</td>
                    <td className="currency warning">{formatCurrency(row.open_amount)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </section>

        {/* Pipeline by Product */}
        <section className="card">
          <h2>Pipeline by Product</h2>
          <div className="table-container">
            <table>
              <thead>
                <tr>
                  <th>Product</th>
                  <th>Total Amount</th>
                  <th>Deal Count</th>
                  <th>Avg Deal Size</th>
                </tr>
              </thead>
              <tbody>
                {productData.map((row, idx) => (
                  <tr key={idx}>
                    <td className="product-name">{row.product}</td>
                    <td className="currency">{formatCurrency(row.total_amount)}</td>
                    <td className="center">{row.deal_count}</td>
                    <td className="currency">{formatCurrency(row.avg_deal_size)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </section>

        {/* Real-Time Last Month Sales (Live from Snowflake) */}
        <section className="card">
          <h2>Last Month Sales 🔴 LIVE</h2>
          <div className="table-container">
            <table>
              <thead>
                <tr>
                  <th>Product</th>
                  <th>Region</th>
                  <th>Total Amount</th>
                  <th>Deal Count</th>
                  <th>Closed Amount</th>
                </tr>
              </thead>
              <tbody>
                {lastMonthData.map((row, idx) => (
                  <tr key={idx}>
                    <td className="product-name">{row.product}</td>
                    <td>{row.region}</td>
                    <td className="currency">{formatCurrency(row.total_amount)}</td>
                    <td className="center">{row.deal_count}</td>
                    <td className="currency success">{formatCurrency(row.closed_amount)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          <p style={{marginTop: '10px', color: '#718096', fontSize: '0.9rem'}}>
            ⚡ This data is queried live from Snowflake on every refresh
          </p>
        </section>

        {/* Summary Stats */}
        <section className="card stats">
          <h2>Summary</h2>
          <div className="stats-grid">
            <div className="stat">
              <div className="stat-label">Total Pipeline</div>
              <div className="stat-value">
                {formatCurrency(
                  regionData.reduce((sum, r) => sum + r.total_amount, 0)
                )}
              </div>
            </div>
            <div className="stat">
              <div className="stat-label">Total Deals</div>
              <div className="stat-value">
                {regionData.reduce((sum, r) => sum + r.deal_count, 0)}
              </div>
            </div>
            <div className="stat">
              <div className="stat-label">Closed Amount</div>
              <div className="stat-value success">
                {formatCurrency(
                  regionData.reduce((sum, r) => sum + r.closed_amount, 0)
                )}
              </div>
            </div>
            <div className="stat">
              <div className="stat-label">Open Amount</div>
              <div className="stat-value warning">
                {formatCurrency(
                  regionData.reduce((sum, r) => sum + r.open_amount, 0)
                )}
              </div>
            </div>
          </div>
        </section>
      </div>

      <footer className="footer">
        <button onClick={fetchData} className="refresh-btn">
          Refresh Data
        </button>
        <span className="last-updated">
          Last updated: {new Date().toLocaleTimeString()}
        </span>
      </footer>
    </div>
  )
}

export default App