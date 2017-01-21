'use strict';

import React, {
  NativeModules,
  NativeEventEmitter,
  DeviceEventEmitter, //android
  NativeAppEventEmitter, //ios
  Platform,
  AppState,
} from 'react-native';

const UmengPushModule = NativeModules.UmengPush;

var receiveMessageSubscript, openMessageSubscription;
const UmengPushEmitter = new NativeEventEmitter(UmengPushModule)
var UmengPush = {
	setAlias(alias){
		return UmengPushModule.setAlias(alias);
	},
  setTag(tag){
    UmengPushModule.setTag(tag);
  },
  removeTag(tag){
    UmengPushModule.removeTag(tag);
  },
  getDeviceToken(handler: Function) {
    UmengPushModule.getDeviceToken(handler);
  },
  didReceiveMessage(handler: Function) {

    receiveMessageSubscript = this.addEventListener(UmengPushModule.DidReceiveMessage, message => {
      //处于后台时，拦截收到的消息
      if(AppState.currentState === 'background') {
        return;
      }
      handler(message);
    });
  },

  didOpenMessage(handler: Function) {
    openMessageSubscription = this.addEventListener(UmengPushModule.DidOpenMessage, handler);
  },

  addEventListener(eventName: string, handler: Function) {
    if(Platform.OS === 'android') {
      return DeviceEventEmitter.addListener(eventName, (event) => {
        handler(event);
      });
    }
    else {
      return UmengPushEmitter.addListener(
        eventName, (userInfo) => {
          handler(userInfo);
        });
    }
  },
};

module.exports = UmengPush;
