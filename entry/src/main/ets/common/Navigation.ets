import { router } from '@kit.ArkUI';

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

export enum NavigationSource {
  INITIAL = 'INITIAL',
  MAIN_NAV = 'MAIN_NAV',
  ENTRY = 'ENTRY',
  DETAIL = 'DETAIL',
  LEGACY = 'LEGACY'
}

export enum NavigationFailureReason {
  PAGE_UNAVAILABLE = 'PAGE_UNAVAILABLE',
  ENTRY_UNAVAILABLE = 'ENTRY_UNAVAILABLE'
}

export enum PageAvailability {
  EMBEDDED = 'EMBEDDED',
  ROUTE = 'ROUTE'
}

export class NavigationState {
  currentPage: PageKey;
  selectedMain: MainNavKey;

  constructor(currentPage: PageKey, selectedMain: MainNavKey) {
    this.currentPage = currentPage;
    this.selectedMain = selectedMain;
  }
}

export class PageRegistration {
  page: PageKey;
  owner: MainNavKey;
  availability: PageAvailability;
  routeUrl: string;

  constructor(page: PageKey, owner: MainNavKey, availability: PageAvailability, routeUrl: string) {
    this.page = page;
    this.owner = owner;
    this.availability = availability;
    this.routeUrl = routeUrl;
  }
}

export class NavigationSuccess {
  success: boolean = true;
  previousPage: PageKey;
  currentPage: PageKey;
  mainKey: MainNavKey;
  previousSnapshot: NavigationState;
  nextSnapshot: NavigationState;
  source: NavigationSource;

  constructor(previousSnapshot: NavigationState, nextSnapshot: NavigationState, source: NavigationSource) {
    this.previousPage = previousSnapshot.currentPage;
    this.currentPage = nextSnapshot.currentPage;
    this.mainKey = nextSnapshot.selectedMain;
    this.previousSnapshot = previousSnapshot;
    this.nextSnapshot = nextSnapshot;
    this.source = source;
  }
}

export class NavigationFailure {
  success: boolean = false;
  reason: NavigationFailureReason;
  previousSnapshot: NavigationState;
  source: NavigationSource;

  constructor(reason: NavigationFailureReason, previousSnapshot: NavigationState, source: NavigationSource) {
    this.reason = reason;
    this.previousSnapshot = previousSnapshot;
    this.source = source;
  }
}

export type NavigationResult = NavigationSuccess | NavigationFailure;

export class AppShellRouteParams {
  page: string;
  serverId: string;
  serverName: string;
  constructor(page: string, serverId: string = '', serverName: string = '') {
    this.page = page;
    this.serverId = serverId;
    this.serverName = serverName;
  }
}

export class ServerDetailRouteParams {
  serverId: string;
  constructor(serverId: string) { this.serverId = serverId; }
}

export class PveNodeDetailRouteParams {
  clusterId: string;
  node: string;
  constructor(clusterId: string, node: string) { this.clusterId = clusterId; this.node = node; }
}

export class VmDetailRouteParams {
  clusterId: string;
  node: string;
  vmid: number;
  constructor(clusterId: string, node: string, vmid: number) {
    this.clusterId = clusterId;
    this.node = node;
    this.vmid = vmid;
  }
}

export class TerminalRouteParams {
  serverId: string;
  serverName: string;
  constructor(serverId: string, serverName: string) { this.serverId = serverId; this.serverName = serverName; }
}

export class ServerFormRouteParams {
  serverId: string;
  constructor(serverId: string = '') { this.serverId = serverId; }
}

export class GameHistoryRouteParams {
  game: string;
  constructor(game: string) { this.game = game; }
}

export class NavigationRouteOptions {
  url: string;
  params: AppShellRouteParams | ServerDetailRouteParams | PveNodeDetailRouteParams | VmDetailRouteParams |
    TerminalRouteParams | ServerFormRouteParams | GameHistoryRouteParams;
  constructor(url: string,
    params: AppShellRouteParams | ServerDetailRouteParams | PveNodeDetailRouteParams | VmDetailRouteParams |
    TerminalRouteParams | ServerFormRouteParams | GameHistoryRouteParams) {
    this.url = url;
    this.params = params;
  }
}

export class PageParameterResult {
  valid: boolean;
  value: PageKey | null;
  constructor(valid: boolean, value: PageKey | null) { this.valid = valid; this.value = value; }
}

export class ServerDetailParameterResult {
  valid: boolean;
  value: ServerDetailRouteParams | null;
  constructor(valid: boolean, value: ServerDetailRouteParams | null) { this.valid = valid; this.value = value; }
}

export class PveNodeDetailParameterResult {
  valid: boolean;
  value: PveNodeDetailRouteParams | null;
  constructor(valid: boolean, value: PveNodeDetailRouteParams | null) { this.valid = valid; this.value = value; }
}

export class VmDetailParameterResult {
  valid: boolean;
  value: VmDetailRouteParams | null;
  constructor(valid: boolean, value: VmDetailRouteParams | null) { this.valid = valid; this.value = value; }
}

const PAGE_REGISTRY: PageRegistration[] = [
  new PageRegistration(PageKey.Index, MainNavKey.Index, PageAvailability.EMBEDDED, 'pages/AppShell'),
  new PageRegistration(PageKey.Servers, MainNavKey.Servers, PageAvailability.EMBEDDED, 'pages/AppShell'),
  new PageRegistration(PageKey.Pve, MainNavKey.Pve, PageAvailability.EMBEDDED, 'pages/AppShell'),
  new PageRegistration(PageKey.Toolbox, MainNavKey.Toolbox, PageAvailability.EMBEDDED, 'pages/AppShell'),
  new PageRegistration(PageKey.More, MainNavKey.More, PageAvailability.EMBEDDED, 'pages/AppShell'),
  new PageRegistration(PageKey.Terminal, MainNavKey.Toolbox, PageAvailability.EMBEDDED, 'pages/AppShell'),
  new PageRegistration(PageKey.Files, MainNavKey.Toolbox, PageAvailability.EMBEDDED, 'pages/AppShell'),
  new PageRegistration(PageKey.Commands, MainNavKey.Toolbox, PageAvailability.EMBEDDED, 'pages/AppShell'),
  new PageRegistration(PageKey.Batch, MainNavKey.Toolbox, PageAvailability.EMBEDDED, 'pages/AppShell'),
  new PageRegistration(PageKey.Games, MainNavKey.Toolbox, PageAvailability.EMBEDDED, 'pages/AppShell'),
  new PageRegistration(PageKey.Alerts, MainNavKey.More, PageAvailability.EMBEDDED, 'pages/AppShell'),
  new PageRegistration(PageKey.Settings, MainNavKey.More, PageAvailability.EMBEDDED, 'pages/AppShell'),
  new PageRegistration(PageKey.ServerDetail, MainNavKey.Servers, PageAvailability.ROUTE, 'pages/ServerDetail'),
  new PageRegistration(PageKey.PveNodeDetail, MainNavKey.Pve, PageAvailability.ROUTE, 'pages/PveNodeDetail'),
  new PageRegistration(PageKey.VmDetail, MainNavKey.Pve, PageAvailability.ROUTE, 'pages/VmDetail')
];

function copyState(state: NavigationState): NavigationState {
  return new NavigationState(state.currentPage, state.selectedMain);
}

function validIdentifier(value: string): boolean {
  return value.trim().length > 0;
}

export function isMainNavKey(key: string): boolean {
  return key === MainNavKey.Index || key === MainNavKey.Servers || key === MainNavKey.Pve ||
    key === MainNavKey.Toolbox || key === MainNavKey.More;
}

export function pageOwner(page: PageKey): MainNavKey {
  const registration: PageRegistration | null = NavigationFacade.registration(page);
  return registration === null ? MainNavKey.More : registration.owner;
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

export class NavigationFacade {
  static registration(page: PageKey): PageRegistration | null {
    for (let index: number = 0; index < PAGE_REGISTRY.length; index++) {
      if (PAGE_REGISTRY[index].page === page) return PAGE_REGISTRY[index];
    }
    return null;
  }

  static pageParameter(value: string): PageParameterResult {
    const page: PageKey | null = pageFromString(value.trim());
    return new PageParameterResult(page !== null, page);
  }

  static serverDetailParameters(params: ServerDetailRouteParams | null): ServerDetailParameterResult {
    const serverId: string = params === null ? '' : params.serverId.trim();
    return validIdentifier(serverId) ? new ServerDetailParameterResult(true, new ServerDetailRouteParams(serverId)) :
      new ServerDetailParameterResult(false, null);
  }

  static pveNodeDetailParameters(params: PveNodeDetailRouteParams | null): PveNodeDetailParameterResult {
    const clusterId: string = params === null ? '' : params.clusterId.trim();
    const node: string = params === null ? '' : params.node.trim();
    return validIdentifier(clusterId) && validIdentifier(node) ?
      new PveNodeDetailParameterResult(true, new PveNodeDetailRouteParams(clusterId, node)) :
      new PveNodeDetailParameterResult(false, null);
  }

  static vmDetailParameters(params: VmDetailRouteParams | null): VmDetailParameterResult {
    const clusterId: string = params === null ? '' : params.clusterId.trim();
    const node: string = params === null ? '' : params.node.trim();
    const vmid: number = params === null ? 0 : params.vmid;
    return validIdentifier(clusterId) && validIdentifier(node) && vmid > 0 ?
      new VmDetailParameterResult(true, new VmDetailRouteParams(clusterId, node, vmid)) :
      new VmDetailParameterResult(false, null);
  }

  static navigate(previous: NavigationState, target: PageKey, source: NavigationSource): NavigationResult {
    const oldSnapshot: NavigationState = copyState(previous);
    const registration: PageRegistration | null = NavigationFacade.registration(target);
    if (registration === null || registration.availability !== PageAvailability.EMBEDDED) {
      const reason: NavigationFailureReason = source === NavigationSource.ENTRY ?
        NavigationFailureReason.ENTRY_UNAVAILABLE : NavigationFailureReason.PAGE_UNAVAILABLE;
      return new NavigationFailure(reason, oldSnapshot, source);
    }
    const nextSnapshot: NavigationState = new NavigationState(target, registration.owner);
    return new NavigationSuccess(oldSnapshot, nextSnapshot, source);
  }

  static navigateLegacy(previous: NavigationState, target: string, source: NavigationSource): NavigationResult {
    const parsed: PageParameterResult = NavigationFacade.pageParameter(target);
    if (!parsed.valid || parsed.value === null) {
      return new NavigationFailure(NavigationFailureReason.PAGE_UNAVAILABLE, copyState(previous), source);
    }
    return NavigationFacade.navigate(previous, parsed.value, source);
  }

  static async openPage(previous: NavigationState, target: PageKey, source: NavigationSource,
    replace: boolean): Promise<NavigationResult> {
    const result: NavigationResult = NavigationFacade.navigate(previous, target, source);
    if (!result.success) return result;
    const options: NavigationRouteOptions = new NavigationRouteOptions('pages/AppShell',
      new AppShellRouteParams(target));
    try {
      if (replace) await router.replaceUrl(options);
      else await router.pushUrl(options);
      return result;
    } catch (e) {
      return new NavigationFailure(NavigationFailureReason.PAGE_UNAVAILABLE, copyState(previous), source);
    }
  }

  static async openTerminal(previous: NavigationState, serverId: string, serverName: string): Promise<NavigationResult> {
    const oldSnapshot: NavigationState = copyState(previous);
    if (!validIdentifier(serverId) && !validIdentifier(serverName)) {
      return new NavigationFailure(NavigationFailureReason.ENTRY_UNAVAILABLE, oldSnapshot, NavigationSource.ENTRY);
    }
    const result: NavigationResult = NavigationFacade.navigate(previous, PageKey.Terminal, NavigationSource.ENTRY);
    if (!result.success) return result;
    const options: NavigationRouteOptions = new NavigationRouteOptions('pages/AppShell',
      new AppShellRouteParams(PageKey.Terminal, serverId.trim(), serverName.trim()));
    try {
      await router.pushUrl(options);
      return result;
    } catch (e) {
      return new NavigationFailure(NavigationFailureReason.ENTRY_UNAVAILABLE, oldSnapshot, NavigationSource.ENTRY);
    }
  }

  static async openServerDetail(previous: NavigationState, serverId: string): Promise<NavigationResult> {
    const params: ServerDetailRouteParams = new ServerDetailRouteParams(serverId.trim());
    return NavigationFacade.openDetail(previous, PageKey.ServerDetail, params, validIdentifier(params.serverId));
  }

  static async openPveNodeDetail(previous: NavigationState, clusterId: string,
    node: string): Promise<NavigationResult> {
    const params: PveNodeDetailRouteParams = new PveNodeDetailRouteParams(clusterId.trim(), node.trim());
    return NavigationFacade.openDetail(previous, PageKey.PveNodeDetail, params,
      validIdentifier(params.clusterId) && validIdentifier(params.node));
  }

  static async openVmDetail(previous: NavigationState, clusterId: string, node: string,
    vmid: number): Promise<NavigationResult> {
    const params: VmDetailRouteParams = new VmDetailRouteParams(clusterId.trim(), node.trim(), vmid);
    return NavigationFacade.openDetail(previous, PageKey.VmDetail, params,
      validIdentifier(params.clusterId) && validIdentifier(params.node) && Number.isInteger(vmid) && vmid > 0);
  }

  private static async openDetail(previous: NavigationState, target: PageKey,
    params: ServerDetailRouteParams | PveNodeDetailRouteParams | VmDetailRouteParams,
    valid: boolean): Promise<NavigationResult> {
    const oldSnapshot: NavigationState = copyState(previous);
    const registration: PageRegistration | null = NavigationFacade.registration(target);
    if (!valid || registration === null || registration.availability !== PageAvailability.ROUTE) {
      return new NavigationFailure(NavigationFailureReason.ENTRY_UNAVAILABLE, oldSnapshot, NavigationSource.DETAIL);
    }
    const options: NavigationRouteOptions = new NavigationRouteOptions(registration.routeUrl, params);
    try {
      await router.pushUrl(options);
      return new NavigationSuccess(oldSnapshot, new NavigationState(target, registration.owner), NavigationSource.DETAIL);
    } catch (e) {
      return new NavigationFailure(NavigationFailureReason.ENTRY_UNAVAILABLE, oldSnapshot, NavigationSource.DETAIL);
    }
  }
}
