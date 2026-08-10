export enum ThemeMode {
  LIGHT = 'light',
  DARK = 'dark'
}

export class ThemePreference {
  followSystem: boolean;
  manualMode: ThemeMode;

  constructor(followSystem: boolean, manualMode: ThemeMode) {
    this.followSystem = followSystem;
    this.manualMode = manualMode;
  }
}

export class GlobalBackgroundPreference {
  globalUri: string;
  visibleStrength: number;

  constructor(globalUri: string, visibleStrength: number) {
    this.globalUri = globalUri;
    this.visibleStrength = visibleStrength;
  }
}
