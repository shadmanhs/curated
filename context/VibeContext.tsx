import React, { createContext, useContext, useState, useEffect } from 'react';
import { VibeProfile } from '../types/vibe';

interface VibeContextType {
  profile: VibeProfile | null;
  rawMarkdown: string;
}

const VibeContext = createContext<VibeContextType>({ profile: null, rawMarkdown: '' });

export function VibeProvider({ children }: { children: React.ReactNode }) {
  const [profile, setProfile] = useState<VibeProfile | null>(null);
  const [rawMarkdown, setRawMarkdown] = useState('');

  useEffect(() => {
    // Load the bundled sample_vibe.md
    const sampleVibe = require('../Resources/sample_vibe.md');
    // TODO: parse YAML profile block from markdown using a YAML parser
    // For now, rawMarkdown is set to the file contents
    setRawMarkdown(String(sampleVibe));
  }, []);

  return (
    <VibeContext.Provider value={{ profile, rawMarkdown }}>
      {children}
    </VibeContext.Provider>
  );
}

export const useVibe = () => useContext(VibeContext);
