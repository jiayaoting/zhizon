export enum MainNavKey {
  Index = 'Index',
  Servers = 'Servers',
  Pve = 'Pve',
  Toolbox = 'Toolbox',
  More = 'More'
}

export enum PageKey {
  Index = 'Index',
  Servers = 'Servers',
  Pve = 'Pve',
  Toolbox = 'Toolbox',
  More = 'More',
  Terminal = 'Terminal',
  Files = 'Files',
  Commands = 'Commands',
  Batch = 'Batch',
  Games = 'Games',
  Alerts = 'Alerts',
  Settings = 'Settings',
  ServerDetail = 'ServerDetail',
  PveNodeDetail = 'PveNodeDetail',
  VmDetail = 'VmDetail'
}

export enum NavigationFailureReason {
  PAGE_UNAVAILABLE = 'PAGE_UNAVAILABLE',
  ENTRY_UNAVAILABLE = 'ENTRY_UNAVAILABLE'
}

export class NavigationSuccess {
  success: boolean = true;
  previousPage: PageKey;
  currentPage: PageKey;
  mainKey: MainNavKey;

  constructor(previousPage: PageKey, currentPage: PageKey, mainKey: MainNavKey) {
    this.previousPage = previousPage;
    this.currentPage = currentPage;
    this.mainKey = mainKey;
  }
}

export class NavigationFailure {
  success: boolean = false;
  reason: NavigationFailureReason;

  constructor(reason: NavigationFailureReason) {
    this.reason = reason;
  }
}

export type NavigationResult = NavigationSuccess | NavigationFailure;

export class NavigationState {
  currentPage: PageKey;
  selectedMain: MainNavKey;

  constructor(currentPage: PageKey, selectedMain: MainNavKey) {
    this.currentPage = currentPage;
    this.selectedMain = selectedMain;
  }
}

export function isMainNavKey(key: string): boolean {
  return key === MainNavKey.Index || key === MainNavKey.Servers || key === MainNavKey.Pve ||
    key === MainNavKey.Toolbox || key === MainNavKey.More;
}

export function pageOwner(page: PageKey): MainNavKey {
  if (page === PageKey.Index) return MainNavKey.Index;
  if (page === PageKey.Servers || page === PageKey.ServerDetail) return MainNavKey.Servers;
  if (page === PageKey.Pve || page === PageKey.PveNodeDetail || page === PageKey.VmDetail) return MainNavKey.Pve;
  if (page === PageKey.Toolbox || page === PageKey.Terminal || page === PageKey.Files ||
    page === PageKey.Commands || page === PageKey.Batch || page === PageKey.Games) {
    return MainNavKey.Toolbox;
  }
  return MainNavKey.More;
}

export function pageFromString(key: string): PageKey | null {
  if (key === PageKey.Index) return PageKey.Index;
  if (key === PageKey.Servers) return PageKey.Servers;
  if (key === PageKey.Pve) return PageKey.Pve;
  if (key === PageKey.Toolbox) return PageKey.Toolbox;
  if (key === PageKey.More) return PageKey.More;
  if (key === PageKey.Terminal) return PageKey.Terminal;
  if (key === PageKey.Files) return PageKey.Files;
  if (key === PageKey.Commands) return PageKey.Commands;
  if (key === PageKey.Batch) return PageKey.Batch;
  if (key === PageKey.Games) return PageKey.Games;
  if (key === PageKey.Alerts) return PageKey.Alerts;
  if (key === PageKey.Settings) return PageKey.Settings;
  if (key === PageKey.ServerDetail) return PageKey.ServerDetail;
  if (key === PageKey.PveNodeDetail) return PageKey.PveNodeDetail;
  if (key === PageKey.VmDetail) return PageKey.VmDetail;
  return null;
}

export function mainPage(key: MainNavKey): PageKey {
  if (key === MainNavKey.Index) return PageKey.Index;
  if (key === MainNavKey.Servers) return PageKey.Servers;
  if (key === MainNavKey.Pve) return PageKey.Pve;
  if (key === MainNavKey.Toolbox) return PageKey.Toolbox;
  return PageKey.More;
}
