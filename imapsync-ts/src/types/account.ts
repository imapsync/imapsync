export interface ImapAccount {
  host: string;
  port: number;
  user: string;
  auth: {
    pass?: string;
    accessToken?: string;
  };
  tls: boolean;
}

export interface FolderInfo {
  path: string;
  delimiter: string;
  specialUse?: string;
  subscribed: boolean;
}

export interface MessageInfo {
  uid: number;
  flags: Set<string>;
  internalDate: Date;
  size: number;
  envelope?: {
    subject: string;
    from: { address: string }[];
    date: Date;
    messageId?: string;
  };
  labels?: Set<string>;
}

export interface FolderStatus {
  path: string;
  exists: number;
  uidValidity: string;
  uidNext: number;
  highestModseq?: string;
}

export interface AppendResult {
  destination: string;
  uid: number;
  uidValidity: string;
}
