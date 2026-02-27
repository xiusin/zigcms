import { createPinia } from 'pinia';
import useAppStore from './modules/app';
import useUserStore from './modules/user';
import useTabBarStore from './modules/tab-bar';
import useFeedbackStore from './modules/feedback';
import useFeedbackNotificationStore from './modules/feedback-notification';

const pinia = createPinia();

export {
  useAppStore,
  useUserStore,
  useTabBarStore,
  useFeedbackStore,
  useFeedbackNotificationStore,
};
export default pinia;
