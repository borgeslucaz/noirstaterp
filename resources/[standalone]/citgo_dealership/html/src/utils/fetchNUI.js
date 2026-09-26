export const fetchNUI = async (eventName, data = {}) => {
  try {
    const r = await fetch(`https://citgo_dealership/${eventName}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(data),
    })
    return await r.json()
  } catch {
    return null
  }
}
