export type DownedState = 'laststand' | 'dead';

export type DoctorStage = 'idle' | 'enroute' | 'walking' | 'treating' | 'done' | 'failed';

export interface DoctorInfo {
  stage: DoctorStage;
  reason?: string;
  duration?: number;
}

export interface DeathSnapshot {
  state: DownedState;
  seconds: number;
  canRespawn: boolean;
  emsOnDuty: number;
  doctorAvailable: boolean;
  doctorWait: number;
  price: number;
  reviveTime: number;
  alertCooldown: number;
  doctor: DoctorInfo;
}

export interface ActionResult {
  ok: boolean;
  message?: string;
}
