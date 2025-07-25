// Learn more https://docs.expo.io/guides/customizing-metro

const { getDefaultConfig } = require('expo/metro-config');      // Expo projects
const exclusionList        = require('metro-config/src/defaults/exclusionList');
const path= require('path');


/** @type {import('expo/metro-config').MetroConfig} */
const config = getDefaultConfig(__dirname);

config.resolver.blockList = exclusionList([
    new RegExp(`${path.resolve(__dirname, 'server')
        .replace(/[/\\]/g, '[/\\\\]')}` + '[/\\\\].*')
]);


module.exports = config;
