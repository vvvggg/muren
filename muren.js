#!/usr/bin/env node
'use strict'

const App = ((() => {

  // Load in required libs
  const cli = require('commander')
  const blessed = require('blessed')
  const VERSION = require('./package.json').version
  const glob = require('glob')
  const fs = require('fs')
  const path = require('path')

  // Defaults
  let themes = ''
  let loadedTheme
  let program = blessed.program()
  let screen                                     // Instance of blessed screen

var testdata_result = [
  ['F', 'Name',                                'Play',  'Fmt', 'kbps',   'MB' ],
  [ '', '..',                                      '',     '',     '',     '' ],
  [ '', 'Die Apokalyptischen Reiter/',     '13:50:32',  'dir',     '', '3893' ],
  [ '', '  1997 - Soft & Stronger/',          '48:52',  'dir',     '',  '326' ],
  ['*', '    03 - Iron Fist.m4a',              '2:33', 'ALAC', '1131',   '19' ],
  ['*', '    04 - The Almighty.m4a',           '2:45', 'ALAC', '1131',   '20' ],
  ['*', '    05 - Execute.m4a',                '3:10', 'ALAC', '1131',   '23' ],
  ['*', '    06 - Downfall.m4a',               '3:03', 'ALAC', '1131',   '22' ],
  ['*', '    07 - Instinct.m4a',               '3:48', 'ALAC', '1131',   '27' ],
  ['*', '    03 - Iron Fist.m4a',              '2:33', 'ALAC', '1131',   '19' ],
  ['*', '    04 - The Almighty.m4a',           '2:45', 'ALAC', '1131',   '20' ],
  ['*', '    05 - Execute.m4a',                '3:10', 'ALAC', '1131',   '23' ],
  ['*', '    06 - Downfall.m4a',               '3:03', 'ALAC', '1131',   '22' ],
  ['*', '    07 - Instinct.m4a',               '3:48', 'ALAC', '1131',   '27' ],
]


  // Set up the commander instance and add the required options
  cli
    .option('-t, --theme  [name]', `set the muren theme [${themes}]`, 'muren')
    .option('--quit-after [seconds]', 'Quits muren after interval', '0')
    .version(VERSION)
    .parse(process.argv)


  const applyTheme = () => {

    // get themes
    const files = glob.sync(path.join(__dirname, 'themes', '*.json'))
    for (var i = 0; i < files.length; i++) {
      let themeName = files[i].replace(path.join(__dirname, 'themes') + path.sep, '').replace('.json', '')
      themes += `${themeName}|`
    }
    themes = themes.slice(0, -1)

    // theming here
    let theme
    if (typeof process.theme !== 'undefined') {
      theme = process.theme
    } else {
      theme = cli.theme
    }

    try {
      loadedTheme = require(`./themes/${theme}.json`)
    } catch (e) {
      console.log(`The theme '${theme}' does not exist.`)
      process.exit(1)
    }

  }


  // construct the footer box
  const drawFooter = () => {

    let text = 'Hello there{|}'

    const commands = {
      'F1' : 'Help',
      'F10': 'Exit',
    }
    for (const c in commands) {
      const command = commands[c]
      text += ` {white-bg}{black-fg}${c}{/black-fg}{/white-bg}:${command}`
    }

    const footer = blessed.box({
      parent: screen,
      bottom: '',
      height: 1,
      width : '100%',
      tags  : true,
      bg    : loadedTheme.footer.bg,
      fg    : loadedTheme.footer.fg,
    })

    footer.setContent(text)
    screen.append(footer)

  }

  const drawFileManResult = () => {

    const FileManResult = blessed.listtable({
      parent       : screen,
      bottom       : +1,                             // + footer.height
      left         : 0,
      padding      : 0,
      width        : '100%',
      height       : '36%',                          // @TODO: make dynamic
      data         : null,
      keys         : true,
      tags         : true,
      label        : '{blue-bg}{white-fg}Result:{/white-fg}{/blue-bg}',
      border       : 'line',
      noCellBorders:  true,
      align        : 'left',
      style        : {
        fg    : 'white',
        bg    : 'blue',
        border: {
          fg: 'white',
          bg: 'blue',
        },
        header: {
          fg  : 'white',
          bg  : 'blue',
          bold: 'true',
        },
        cell  : {
          selected: {
            fg: 'blue',
            bg: 'white',
          },
        },
      },
      // @BUG? the scrollbar overrides by 'line' border
      // scrollbar: {
      //   fg: 'white',
      //   bg: 'blue',
      //   ch: '*',
      // },
    })

    FileManResult.setData(testdata_result)  // @TODO: replace w/live data
    screen.append(FileManResult)
    FileManResult.focus()
  }

  return {

    init () {

      // Quits running muren after so many seconds
      // This is mainly for perf testing.
      if (cli['quitAfter'] !== '0') {
        setTimeout(() => {
          process.exit(0)
        }, parseInt(cli['quitAfter'], 10) * 1000)
      }

      // Create a screen object.
      screen = blessed.screen({
        tput    : true,
        smartCSR: true,
        // dump    : __dirname + '/log/muren.log',
        warnings: true,
        fullUnicode: true,
      })

      // global keypress handlers
      screen.key(['f10', 'C-c'], function(ch, key) {
        return process.exit(0)
      })

      applyTheme()
      drawFooter()
      drawFileManResult()
      screen.render()
    }

  }

})())

App.init()
