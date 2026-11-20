import React from 'react';
import { Composition } from 'remotion';
import { Ad, FPS, scenePlan } from './Ad';

export const RemotionRoot: React.FC = () => (
  <Composition id="Ad" component={Ad} durationInFrames={scenePlan().total} fps={FPS} width={1080} height={1920} />
);
