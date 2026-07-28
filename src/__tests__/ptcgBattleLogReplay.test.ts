import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  BATTLE_LOG_SCHEMA_VERSION,
  BattleLogReplayError,
  replayBattleLog,
} from '../lib/ptcgBattleLogReplay.js';

const fixtures = path.join(path.dirname(fileURLToPath(import.meta.url)), 'fixtures');
const load = (name: string): unknown =>
  JSON.parse(fs.readFileSync(path.join(fixtures, name), 'utf8'));

describe('replayBattleLog', () => {
  it('preserves optional retreat energy costs for board summaries', () => {
    const log = load('battle-log.snapshot.json') as {
      initialState: {
        players: Record<string, { active: Record<string, unknown> | null }>;
      };
    };
    const player = Object.values(log.initialState.players).find((value) => value.active !== null);
    if (!player?.active) throw new Error('fixture must contain an active Pokemon');
    player.active.retreatCost = ['無', '無'];

    const snapshot = replayBattleLog(log).at(0);
    const active = Object.values(snapshot!.state.players).find((board) => board.active)?.active;
    expect(active?.retreatCost).toEqual(['無', '無']);
  });

  it('reconstructs the board after every event in order', () => {
    const snapshots = replayBattleLog(load('battle-log.valid.json'));
    expect(snapshots).toHaveLength(8);
    expect(snapshots.map((snapshot) => snapshot.eventIndex)).toEqual([-1, 0, 1, 2, 3, 4, 5, 6]);
    expect(snapshots[1].state.players.matsu.active?.id).toBe('m1');
    expect(snapshots[3].state.players.matsu.active?.energy).toEqual(['fire']);
    expect(snapshots[4].state.players.take.active?.damage).toBe(90);
    expect(snapshots[5].state.players.take.active).toBeNull();
    expect(snapshots[5].state.players.take.discard).toEqual(['t1']);
    expect(snapshots[6].state.players.matsu.prizesRemaining).toBe(5);
    expect(snapshots[7].state.winner).toBe('matsu');
  });

  it('is deterministic and does not mutate its input', () => {
    const log = load('battle-log.valid.json');
    const before = JSON.stringify(log);
    expect(replayBattleLog(log)).toEqual(replayBattleLog(log));
    expect(JSON.stringify(log)).toBe(before);
  });

  it('reports an unsupported event with its event index', () => {
    expect(() => replayBattleLog(load('battle-log.invalid.json'))).toThrow(
      new BattleLogReplayError('unsupported event type "teleport"', 0)
    );
  });

  it('rejects unsupported schema versions', () => {
    const log = load('battle-log.valid.json') as Record<string, unknown>;
    log.schemaVersion = 'ptcg-battle-log/v2';
    expect(() => replayBattleLog(log)).toThrow(
      `unsupported schemaVersion "ptcg-battle-log/v2"; expected "${BATTLE_LOG_SCHEMA_VERSION}"`
    );
  });

  it('rejects an event that violates board invariants', () => {
    const log = load('battle-log.valid.json') as { events: Record<string, unknown>[] };
    log.events[3].amount = 0;
    expect(() => replayBattleLog(log)).toThrow('event[3]: damage amount must be positive');
  });

  it('keeps prior snapshots immutable as later events are applied', () => {
    const snapshots = replayBattleLog(load('battle-log.valid.json'));
    expect(snapshots[3].state.players.take.active?.damage).toBe(0);
    expect(snapshots[4].state.players.take.active?.damage).toBe(90);
  });

  it('preserves optional attacks in concrete-card snapshot logs', () => {
    const snapshots = replayBattleLog(load('battle-log.snapshot.json'));
    expect(snapshots[0].state.players['あなた'].active?.attacks).toEqual([
      { name: 'エレキサークル', damage: '60', cost: ['雷'] },
      { name: 'サンダーボルト', damage: '200', cost: ['雷', '雷', '無'] },
    ]);
  });

  it('keeps known hand cards synchronized without revealing unknown hands', () => {
    const log = load('battle-log.valid.json') as any;
    log.initialState.players.matsu.handCount = 1;
    log.initialState.players.matsu.hand = [
      { id: 'm1', name: 'Matsu EX', maxHp: 100, damage: 0, energy: [] },
    ];
    log.events = [
      log.events[0],
      {
        type: 'draw',
        player: 'matsu',
        count: 1,
        cards: [{ id: 'm2', name: '博士の研究', maxHp: 0, damage: 0, energy: [] }],
      },
    ];

    const snapshots = replayBattleLog(log);
    expect(snapshots[1].state.players.matsu.hand).toEqual([]);
    expect(snapshots[2].state.players.matsu.hand?.map((card) => card.name)).toEqual(['博士の研究']);
    expect(snapshots[2].state.players.take.hand).toBeUndefined();
  });

  it('keeps both players on the same turn snapshot at every turn boundary', () => {
    const log = load('battle-log.valid.json') as any;
    log.events = [
      { type: 'end-turn', nextPlayer: 'take' },
      { type: 'end-turn', nextPlayer: 'matsu' },
    ];

    const snapshots = replayBattleLog(log);
    expect(snapshots.map(({ state }) => [state.turn, state.currentPlayer])).toEqual([
      [1, 'matsu'],
      [2, 'take'],
      [3, 'matsu'],
    ]);
    expect(Object.keys(snapshots[1].state.players)).toEqual(['matsu', 'take']);
  });

  it('supports up to five named bench cards and safe missing names', () => {
    const log = load('battle-log.valid.json') as any;
    log.initialState.players.matsu.bench = Array.from({ length: 5 }, (_, index) => ({
      id: `bench-${index}`,
      name: index === 4 ? '' : `ポケモン${index + 1}`,
      maxHp: 100,
      damage: 0,
      energy: [],
    }));
    log.events = [];

    const snapshot = replayBattleLog(log)[0];
    expect(snapshot.state.players.matsu.bench).toHaveLength(5);
    expect(snapshot.state.players.matsu.bench[4].name).toBe('');
  });

  it('preserves trainer usage descriptions and permits a safe fallback', () => {
    const log = load('battle-log.valid.json') as any;
    log.events = [
      {
        type: 'play-trainer',
        player: 'matsu',
        cardName: '博士の研究',
        effect: '手札をすべてトラッシュし、山札を7枚引く',
      },
      { type: 'play-trainer', player: 'take', cardName: '', effect: '' },
    ];

    const snapshots = replayBattleLog(log);
    expect(snapshots[1].event).toMatchObject({ cardName: '博士の研究' });
    expect(snapshots[2].state.turn).toBe(1);
  });
});
