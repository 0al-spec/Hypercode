/*

  # config.hcs (Provides context-dependent behavior)

 */

import { default_ } from './default';
import { production } from './production';
import { staging } from './staging';

export const config = {
  default: default_,
  production,
  staging,
};
