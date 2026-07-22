import type { Metadata } from 'next';
import { Inter, Inter_Tight } from 'next/font/google';
import './globals.css';

import { WalletProvider } from "@/components/wallet-provider"

const inter = Inter({ subsets: ['latin'], variable: '--font-body' });
const interTight = Inter_Tight({ subsets: ['latin'], variable: '--font-display' });

export const metadata: Metadata = {
  title: 'Stream Vault',
  description: 'Capital streaming for Celo, in your pocket.',
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body className={`${inter.variable} ${interTight.variable} font-sans bg-[#EDEDEF]`}>
        <WalletProvider>
          <div className="flex min-h-screen justify-center">
            <div className="relative flex w-full max-w-[430px] flex-col bg-white min-h-screen shadow-[0_0_60px_rgba(0,0,0,0.08)]">
              {children}
            </div>
          </div>
        </WalletProvider>
      </body>
    </html>
  );
}
