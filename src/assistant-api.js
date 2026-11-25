/** Invoke the server-side assistant without exposing secrets in the browser. */
export async function requestAssistant(db, message) {
  let result;
  try {
    result = await db.functions.invoke('uniflow-ai', {body:{message}});
  } catch {
    throw new Error('Could not reach UniFlow AI. Check your connection and try again.');
  }
  if (result.error) {
    let detail;
    try {
      const response = result.error.context;
      if (response && typeof response.json === 'function') detail = await response.json();
    } catch { /* The service may return a non-JSON error. */ }
    if (typeof detail?.error === 'string' && detail.error.length <= 300) throw new Error(detail.error);
    throw new Error('UniFlow AI is unavailable. Please try again.');
  }
  if (typeof result.data?.answer !== 'string' || !result.data.answer.trim()) {
    throw new Error('UniFlow AI returned an invalid response. Please try again.');
  }
  return result.data.answer;
}
