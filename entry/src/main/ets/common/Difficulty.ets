import { router } from '@kit.ArkUI';
import { PageKey } from './Navigation';

export enum DifficultyLevel {
  VERY_EASY = 'VERY_EASY',
  EASY = 'EASY',
  MEDIUM = 'MEDIUM',
  HARD = 'HARD',
  HELL = 'HELL'
}

export class DifficultyDefinition {
  level: DifficultyLevel;
  label: string;
  icon: string;
  description: string;

  constructor(level: DifficultyLevel, label: string, icon: string, description: string) {
    this.level = level;
    this.label = label;
    this.icon = icon;
    this.description = description;
  }
}

export const DIFFICULTY_DEFINITIONS: DifficultyDefinition[] = [
  new DifficultyDefinition(DifficultyLevel.VERY_EASY, '超简单', '😊', '轻松上手'),
  new DifficultyDefinition(DifficultyLevel.EASY, '简单', '🙂', '节奏舒缓'),
  new DifficultyDefinition(DifficultyLevel.MEDIUM, '中等', '🤔', '经典体验'),
  new DifficultyDefinition(DifficultyLevel.HARD, '困难', '😈', '快速挑战'),
  new DifficultyDefinition(DifficultyLevel.HELL, '地狱', '💀', '极限速度')
];

export function difficultyLabel(level: DifficultyLevel): string {
  for (const definition of DIFFICULTY_DEFINITIONS) {
    if (definition.level === level) return definition.label;
  }
  return '中等';
}

export enum GameId {
  TETRIS = 'TETRIS',
  GAME_2048 = 'GAME_2048',
  SNAKE = 'SNAKE',
  MINESWEEPER = 'MINESWEEPER',
  BREAKOUT = 'BREAKOUT'
}

export enum GameLaunchFailureCode {
  INVALID_GAME_ARGUMENT = 'INVALID_GAME_ARGUMENT',
  GAME_ROUTE_UNAVAILABLE = 'GAME_ROUTE_UNAVAILABLE'
}

export class GameLaunchRequest {
  gameId: GameId;
  difficulty: DifficultyLevel;
  sourcePage: PageKey;
  launchVersion: number;

  constructor(gameId: GameId, difficulty: DifficultyLevel, sourcePage: PageKey, launchVersion: number) {
    this.gameId = gameId;
    this.difficulty = difficulty;
    this.sourcePage = sourcePage;
    this.launchVersion = launchVersion;
  }
}

export class GameRouteParams {
  gameId: string;
  difficulty: string;
  sourcePage: string;
  launchVersion: string;

  constructor(request: GameLaunchRequest) {
    this.gameId = request.gameId;
    this.difficulty = request.difficulty;
    this.sourcePage = request.sourcePage;
    this.launchVersion = request.launchVersion.toString();
  }
}

export class GameRegistration {
  gameId: GameId;
  routeUrl: string;
  title: string;

  constructor(gameId: GameId, routeUrl: string, title: string) {
    this.gameId = gameId;
    this.routeUrl = routeUrl;
    this.title = title;
  }
}

export class GameLaunchResult {
  success: boolean;
  request: GameLaunchRequest | null;
  failureCode: GameLaunchFailureCode | null;
  message: string;

  constructor(success: boolean, request: GameLaunchRequest | null,
    failureCode: GameLaunchFailureCode | null, message: string) {
    this.success = success;
    this.request = request;
    this.failureCode = failureCode;
    this.message = message;
  }
}

export const GAME_REGISTRY: GameRegistration[] = [
  new GameRegistration(GameId.TETRIS, 'pages/Tetris', '俄罗斯方块'),
  new GameRegistration(GameId.GAME_2048, 'pages/Game2048', '2048'),
  new GameRegistration(GameId.SNAKE, 'pages/Snake', '贪吃蛇'),
  new GameRegistration(GameId.MINESWEEPER, 'pages/Minesweeper', '扫雷'),
  new GameRegistration(GameId.BREAKOUT, 'pages/Breakout', '打砖块')
];

export function isDifficultyLevel(value: string): boolean {
  return value === DifficultyLevel.VERY_EASY || value === DifficultyLevel.EASY ||
    value === DifficultyLevel.MEDIUM || value === DifficultyLevel.HARD || value === DifficultyLevel.HELL;
}

function gameIdFromString(value: string): GameId | null {
  if (value === GameId.TETRIS) return GameId.TETRIS;
  if (value === GameId.GAME_2048) return GameId.GAME_2048;
  if (value === GameId.SNAKE) return GameId.SNAKE;
  if (value === GameId.MINESWEEPER) return GameId.MINESWEEPER;
  if (value === GameId.BREAKOUT) return GameId.BREAKOUT;
  return null;
}

function difficultyFromString(value: string): DifficultyLevel | null {
  if (!isDifficultyLevel(value)) return null;
  if (value === DifficultyLevel.VERY_EASY) return DifficultyLevel.VERY_EASY;
  if (value === DifficultyLevel.EASY) return DifficultyLevel.EASY;
  if (value === DifficultyLevel.MEDIUM) return DifficultyLevel.MEDIUM;
  if (value === DifficultyLevel.HARD) return DifficultyLevel.HARD;
  return DifficultyLevel.HELL;
}

function pageFromString(value: string): PageKey | null {
  if (value === PageKey.Games) return PageKey.Games;
  return null;
}

export class GameLaunchFacade {
  private static launchVersion: number = 0;

  static nextVersion(): number {
    GameLaunchFacade.launchVersion += 1;
    return GameLaunchFacade.launchVersion;
  }

  static registration(gameId: GameId): GameRegistration | null {
    for (let index: number = 0; index < GAME_REGISTRY.length; index++) {
      if (GAME_REGISTRY[index].gameId === gameId) return GAME_REGISTRY[index];
    }
    return null;
  }

  static validate(request: GameLaunchRequest, expectedGameId: GameId | null): GameLaunchResult {
    const registration: GameRegistration | null = GameLaunchFacade.registration(request.gameId);
    const validExpectedGame: boolean = expectedGameId === null || expectedGameId === request.gameId;
    const validDifficulty: boolean = isDifficultyLevel(request.difficulty);
    const validSource: boolean = request.sourcePage === PageKey.Games;
    const validVersion: boolean = Number.isInteger(request.launchVersion) && request.launchVersion > 0;
    if (registration === null || !validExpectedGame || !validDifficulty || !validSource || !validVersion) {
      return new GameLaunchResult(false, null, GameLaunchFailureCode.INVALID_GAME_ARGUMENT,
        '游戏启动参数无效，已保留当前页面');
    }
    return new GameLaunchResult(true, request, null, '');
  }

  static parse(params: GameRouteParams | null, expectedGameId: GameId): GameLaunchResult {
    const gameId: GameId | null = gameIdFromString(params === null ? '' : params.gameId.trim());
    const difficulty: DifficultyLevel | null = difficultyFromString(params === null ? '' : params.difficulty.trim());
    const sourcePage: PageKey | null = pageFromString(params === null ? '' : params.sourcePage.trim());
    const launchVersion: number = Number(params === null ? '' : params.launchVersion);
    if (gameId === null || difficulty === null || sourcePage === null) {
      return new GameLaunchResult(false, null, GameLaunchFailureCode.INVALID_GAME_ARGUMENT,
        '游戏启动参数无效，已返回游戏中心');
    }
    const validation: GameLaunchResult = GameLaunchFacade.validate(
      new GameLaunchRequest(gameId, difficulty, sourcePage, launchVersion), expectedGameId);
    if (!validation.success) {
      return new GameLaunchResult(false, null, GameLaunchFailureCode.INVALID_GAME_ARGUMENT,
        '游戏启动参数无效，已返回游戏中心');
    }
    return validation;
  }

  static async open(request: GameLaunchRequest): Promise<GameLaunchResult> {
    const validation: GameLaunchResult = GameLaunchFacade.validate(request, null);
    if (!validation.success) return validation;
    const registration: GameRegistration | null = GameLaunchFacade.registration(request.gameId);
    if (registration === null) {
      return new GameLaunchResult(false, null, GameLaunchFailureCode.INVALID_GAME_ARGUMENT,
        '游戏启动参数无效，已保留当前页面');
    }
    try {
      await router.pushUrl({ url: registration.routeUrl, params: new GameRouteParams(request) });
      return validation;
    } catch (e) {
      return new GameLaunchResult(false, null, GameLaunchFailureCode.GAME_ROUTE_UNAVAILABLE,
        '游戏页面打开失败，请重试');
    }
  }
}
