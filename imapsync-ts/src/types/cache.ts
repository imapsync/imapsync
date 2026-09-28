export interface UidMapping {
  folder: string;
  sourceUid: number;
  destUid: number;
  uidValidity: string;
}

export interface MessageHash {
  folder: string;
  sourceUid: number;
  headerHash: string;
  uidValidity: string;
}
