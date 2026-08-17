import { describe, it, expect } from '@ohos/hypium';
import { DifficultyLevel, GameId, GameLaunchFacade, GameLaunchRequest, GameRouteParams } from '../main/ets/common/Difficulty';
import { PageKey } from '../main/ets/common/Navigation';

export default function GameLaunchFacadeTest() {
  describe('GameLaunchFacadeTest', () => {
    it('keeps selected difficulty in a valid launch request', 0, () => {
      const request = new GameLaunchRequest(GameId.TETRIS, DifficultyLevel.HELL, PageKey.Games, 1);
      const result = GameLaunchFacade.validate(request, GameId.TETRIS);
      expect(result.success).assertTrue();
      expect(result.request).assertEqual(request);
      expect(request.difficulty).assertEqual(DifficultyLevel.HELL);
    });

    it('rejects mismatched game invalid version and unknown route values', 0, () => {
      const wrongGame = new GameLaunchRequest(GameId.SNAKE, DifficultyLevel.EASY, PageKey.Games, 1);
      const invalidVersion = new GameLaunchRequest(GameId.TETRIS, DifficultyLevel.EASY, PageKey.Games, 0);
      const invalidParams = new GameRouteParams(invalidVersion);
      invalidParams.difficulty = 'UNKNOWN';
      expect(GameLaunchFacade.validate(wrongGame, GameId.TETRIS).success).assertFalse();
      expect(GameLaunchFacade.validate(invalidVersion, GameId.TETRIS).success).assertFalse();
      expect(GameLaunchFacade.parse(invalidParams, GameId.TETRIS).success).assertFalse();
    });

    it('supports sudoku registration and launch validation', 0, () => {
      const registration = GameLaunchFacade.registration(GameId.SUDOKU);
      expect(registration !== null).assertTrue();
      expect(registration !== null && registration.routeUrl).assertEqual('pages/Sudoku');
      const request = new GameLaunchRequest(GameId.SUDOKU, DifficultyLevel.HARD, PageKey.Games, 1);
      expect(GameLaunchFacade.validate(request, GameId.SUDOKU).success).assertTrue();
      const params = new GameRouteParams(request);
      expect(GameLaunchFacade.parse(params, GameId.SUDOKU).success).assertTrue();
    });
  });
}
