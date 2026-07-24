export interface PresetConfig {
  host: string;
  port: number;
  tls: boolean;
}

export function gmailPreset(): PresetConfig {
  return { host: 'imap.gmail.com', port: 993, tls: true };
}

export function exchangePreset(): PresetConfig {
  return { host: 'outlook.office365.com', port: 993, tls: true };
}

export function office365Preset(): PresetConfig {
  return { host: 'outlook.office365.com', port: 993, tls: true };
}

export function dominoPreset(): PresetConfig {
  return { host: '', port: 993, tls: true };
}
