import { useEffect } from 'react';
import { ArrowLeft } from 'lucide-react';
import legal from './legalText';
import { SUPPORT_EMAIL } from './config';

// The same Privacy policy and Disclaimer the app shows at /privacy and
// /disclaimer (text generated from legal_pages.dart).
export default function Legal({ kind }) {
  const privacy = kind === 'privacy';
  const sections = privacy ? legal.privacy : legal.disclaimer;

  useEffect(() => {
    window.scrollTo(0, 0);
    document.title = `${privacy ? 'Privacy policy' : 'Disclaimer'} - Stylux`;
  }, [privacy]);

  return (
    <main className="legal" id="main">
      <div className="wrap">
        <article className="doc">
          <a className="back" href="#top">
            <ArrowLeft size={18} /> Back to Stylux
          </a>
          <h1>{privacy ? 'Privacy policy' : 'Disclaimer'}</h1>
          <p className="meta">Stylux · effective {legal.effective}</p>
          <p className="intro">
            {privacy ? 'How Stylux handles the information your salon keeps in it.' : 'What Stylux does and does not promise.'}
          </p>
          {sections.map((s) => (
            <section key={s.heading}>
              <h2>{s.heading}</h2>
              {s.paragraphs.map((p) => (
                <p key={p.slice(0, 40)}>{p}</p>
              ))}
            </section>
          ))}
          <hr style={{ border: 0, borderTop: '1px solid var(--border)', margin: '32px 0 20px' }} />
          <p>
            Questions or requests: write to <a href={`mailto:${SUPPORT_EMAIL}`}>{SUPPORT_EMAIL}</a>. If you are a salon client, you can also
            ask the salon directly.
          </p>
          <p>
            <a href={privacy ? '#/disclaimer' : '#/privacy'}>{privacy ? 'Read the disclaimer' : 'Read the privacy policy'}</a>
          </p>
        </article>
      </div>
    </main>
  );
}
