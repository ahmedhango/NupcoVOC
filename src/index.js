import { NativeModules, NativeEventEmitter } from 'react-native';

const { NupcoVOCModule } = NativeModules;
const emitter = new NativeEventEmitter(NupcoVOCModule);

export const open = ({ url, html }) => NupcoVOCModule.open({ url, html });
export const addListener = (cb) => {
    const sub = emitter.addListener('NupcoVOCEvent', cb);
    return () => sub.remove();
};

export default { open, addListener };


