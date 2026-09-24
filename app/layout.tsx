import type { Metadata } from 'next';
import './globals.css';

export const metadata: Metadata = {
  title: 'CICS Alumni Connect',
  description: 'College of Information and Computing Sciences alumni portal',
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return <html lang="en"><body>{children}</body></html>;
}
