import { router } from '@kit.ArkUI';

export enum MainNavKey {
  Index = 'Index',
  Toolbox = 'Toolbox',
  More = 'More'
}

export enum PageKey {
  Index = 'Index',
  Toolbox = 'Toolbox',
  More = 'More',
  Games = 'Games',
  Settings = 'Settings',
  Chat = 'Chat'
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

export class GameHistoryRouteParams {
  game: string;
  constructor(game: string) { this.game = game; }
}

export class LegalDocRouteParams {
  type: string;
  constructor(type: string) { this.type = type; }
}

export class ChatRouteParams {
  from: string;
  constructor(from: string = '') { this.from = from; }
}

export class NavigationRouteOptions {
  url: string;
  params: AppShellRouteParams | GameHistoryRouteParams;
  constructor(url: string,
    params: AppShellRouteParams | GameHistoryRouteParams) {
    this.url = url;
    this.params = params;
  }
}

export class PageParameterResult {
  valid: boolean;
  value: PageKey | null;
  constructor(valid: boolean, value: PageKey | null) { this.valid = valid; this.value = value; }
}

const PAGE_REGISTRY: PageRegistration[] = [
  new PageRegistration(PageKey.Index, MainNavKey.Index, PageAvailability.EMBEDDED, 'pages/AppShell'),
  new PageRegistration(PageKey.Toolbox, MainNavKey.Toolbox, PageAvailability.EMBEDDED, 'pages/AppShell'),
  new PageRegistration(PageKey.More, MainNavKey.More, PageAvailability.EMBEDDED, 'pages/AppShell'),
  new PageRegistration(PageKey.Games, MainNavKey.Toolbox, PageAvailability.EMBEDDED, 'pages/AppShell'),
  new PageRegistration(PageKey.Settings, MainNavKey.More, PageAvailability.EMBEDDED, 'pages/AppShell')
];

function copyState(state: NavigationState): NavigationState {
  return new NavigationState(state.currentPage, state.selectedMain);
}

function validIdentifier(value: string): boolean {
  return value.trim().length > 0;
}

export function isMainNavKey(key: string): boolean {
  return key === MainNavKey.Index || key === MainNavKey.Toolbox || key === MainNavKey.More;
}

export function pageOwner(page: PageKey): MainNavKey {
  const registration: PageRegistration | null = NavigationFacade.registration(page);
  return registration === null ? MainNavKey.More : registration.owner;
}

export function pageFromString(key: string): PageKey | null {
  if (key === PageKey.Index) return PageKey.Index;
  if (key === PageKey.Toolbox) return PageKey.Toolbox;
  if (key === PageKey.More) return PageKey.More;
  if (key === PageKey.Games) return PageKey.Games;
  if (key === PageKey.Settings) return PageKey.Settings;
  return null;
}

export function mainPage(key: MainNavKey): PageKey {
  if (key === MainNavKey.Index) return PageKey.Index;
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
}
