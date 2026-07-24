export function diffFlags(source: Set<string>, dest: Set<string>): { toAdd: string[]; toRemove: string[] } {
  const toAdd: string[] = [];
  const toRemove: string[] = [];
  for (const flag of source) {
    if (!dest.has(flag)) toAdd.push(flag);
  }
  for (const flag of dest) {
    if (!source.has(flag)) toRemove.push(flag);
  }
  return { toAdd, toRemove };
}
