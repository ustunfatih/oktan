import { Link } from "../router";

export function ComingSoon({ title, phase }: { title: string; phase: string }) {
  return (
    <section className="panel coming-soon">
      <h1 className="page-title">{title}</h1>
      <p className="muted">This screen is built in {phase} of the roadmap.</p>
      <Link to="/" className="link">
        ← Back to the dashboard
      </Link>
    </section>
  );
}
