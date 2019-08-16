require! {
  asciichart
  chalk
  axios
  commander
  fs
  path
  \array-interpolatejs    : { interpolateArray }
  \human-readable-numbers : { toHumanString }
  \lodash/fp              : { get, identity, tail, forEach, last, flatMap, map }
  \lodash/fp              : { values, flatMap, defaultTo }
  \node-fetch             : fetch
  \configstore            : Configstore
  \node-iex-cloud         : { IEXCloudClient }
  \yahoo-stocks           : { lookup, history }
  \scrape-it              : scrapeIt
  \cnn-market             : { cnnMarket }
}

# Comand Line Parsing
commander
  .option '-c, --chart <string>' 'chart for stock symbol e.g. MSFT'
  .option '-i, --interval <string>' 'Interval of price changes: 1m, 1d, 5d, 1mo, 1y'
  .option '-r, --range <string>' 'Range of dates to include: 1m, 1d, 5d, 1mo, 1y'
  .option '-h, --height <int>' 'Height of the chart'
  .option '--width <int>' 'Width of the chart'
  .option '-w, --watch'
  .parse process.argv

interval = commander.interval |> defaultTo "1d"
range    = commander.range    |> defaultTo "5y"
height   = commander.height   |> parseInt       |> defaultTo 14
width    = commander.width    |> parseInt       |> defaultTo 80

# Quotes API
iex = new IEXCloudClient fetch, publishable: \pk_64fdeb84e42e4d239b3e87ab58d76e09

# Constants
[COL_PAD, DELIM_LEN] = [9 109]

# Helper Functions
getQuote = ->> await iex.symbols(it).batch \quote
config = fs.readFileSync('watchlist.json')
    |> JSON.parse
    |> new Configstore(\stock-chart-cli, _)
plusSign = -> if (it > 0) then \+ + it else  it
pad = (.toString!padStart(COL_PAD))
tablePad = (.padEnd(COL_PAD))
colNames = [tablePad \Symbol] ++
<[ Price Change Change% AvgVolume P/E MktCap Week52Low Week52High YTDChange ]>
dollar = -> \$ + it.toFixed(2)
percentage = -> (it * 100).toFixed(2) + \%
humanString = -> if it then toHumanString it

# Colors
red = chalk.red << pad
green = chalk.green << pad
percentColor = ->
    | "-" in it => red it
    | otherwise => green it
numColor = ->
    | it < 0    => red it
    | otherwise => green it
peColor = ->
    | it < 0    => red pad it
    | it < 10   => green it
    | it > 40   => red it
    | otherwise => it
symColor = (price, symbol) ~~>
    | price < 0 => chalk.bold <| red symbol
    | otherwise => chalk.bold <| green symbol

# Table of market data and quotes from watchlist
quotes = ->>
    data = await cnnMarket()
    process.stdout.write((chalk.bold "Dow".padEnd(7)) + data.Dow.padStart(10) + (" [" + data.DowChg + "|" + data.DowChgPcnt + "]").padEnd(20))
    process.stdout.write((chalk.bold "HK".padEnd(7)) + data.Dow.padStart(10) + (" [" + data.DowChg + "|" + data.DowChgPcnt + "]").padEnd(20))
    console.log((chalk.bold "Yield 10y".padEnd(9)) + data.Yield10Y.padStart(10) + (" [" + data.Yield10YChg + "]").padEnd(20))
    process.stdout.write((chalk.bold "Nasdaq".padEnd(7)) + data.Nasdaq.padStart(10) + (" [" + data.NasdaqChg + "|" + data.NasdaqChgPcnt + "]").padEnd(20))
    process.stdout.write((chalk.bold "London".padEnd(7)) + data.London.padStart(10) + (" [" + data.LondonChg + "|" + data.LondonChgPcnt + "]").padEnd(20))
    console.log((chalk.bold "Oil".padEnd(9)) + data.Oil.padStart(10) + (" [" + data.OilChg + "]").padEnd(20))
    process.stdout.write((chalk.bold "S&P500".padEnd(7)) + data.SP500.padStart(10) + (" [" + data.SP500Chg + "|" + data.SP500ChgPcnt + "]").padEnd(20))
    process.stdout.write((chalk.bold "GER".padEnd(7)) + data.Germany.padStart(10) + (" [" + data.GermanyChg + "|" + data.GermanyChgPcnt + "]").padEnd(20))
    console.log((chalk.bold "Gold".padEnd(9)) + data.Gold.padStart(10) + (" [" + data.GoldChg + "]").padEnd(20))
    console.log ""
    console.log map(pad, colNames) * "  "
    console.log "-" * DELIM_LEN
    (await getQuote <| config.get('stocks'))
    |> map 'quote'
    |> map( ->
        [ # Parse API data in human readable format
         it.symbol              |> tablePad     |> symColor it.change
         it.latestPrice         |> dollar
         it.change?.toFixed(2)  |> plusSign     |> numColor
         it.changePercent       |> plusSign     |> percentage |> percentColor
         it.avgTotalVolume      |> humanString
         it.peRatio?.toFixed(1) |> defaultTo "" |> peColor
         it.marketCap           |> humanString
         it.week52Low           |> dollar
         it.week52High          |> dollar
         it.ytdChange           |> percentage   |> plusSign   |> percentColor
        ]
        |> map defaultTo ""
        |> map pad
    )
    |> map(-> it * "  ")
    |> forEach console.log


# Stock chart of a symbol e.g. AAPL
chart = ->>
    (await history(commander.chart, interval: interval, range: range ))
    |> map identity
    |> tail
    |> (flatMap <| map 'close')
    |> interpolateArray width
    |> asciichart.plot(_, height: height)
    |> console.log

# Main function / Entrypoint
do ->> if commander.chart then chart! else quotes!
