import { Component, type ReactNode } from "react";
import { reportClientError } from "./report";

/** Keeps a crash on one screen from blanking the whole app; the top bar and tabs stay usable. */
export class ErrorBoundary extends Component<{ children: ReactNode; resetKey: string }, { error: Error | null }> {
  state = { error: null as Error | null };

  static getDerivedStateFromError(error: Error) {
    return { error };
  }

  componentDidCatch(error: Error) {
    reportClientError("render", error);
  }

  componentDidUpdate(prev: { resetKey: string }) {
    // Moving to another tab, or fresh data arriving, clears the error and tries the screen again.
    if (prev.resetKey !== this.props.resetKey && this.state.error) this.setState({ error: null });
  }

  render() {
    if (!this.state.error) return this.props.children;
    return (
      <section className="panel error-panel" role="alert">
        <h1 className="page-title">This screen hit a problem</h1>
        <p className="muted">It has been reported. Your sheet is unchanged.</p>
        <p className="muted mono small">{this.state.error.message}</p>
        <button type="button" className="btn" onClick={() => location.reload()}>
          Reload
        </button>
      </section>
    );
  }
}
