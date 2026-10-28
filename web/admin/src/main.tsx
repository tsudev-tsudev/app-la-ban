import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { App } from './App';

const goc = document.getElementById('root');
if (goc) {
  createRoot(goc).render(
    <StrictMode>
      <App />
    </StrictMode>,
  );
}
