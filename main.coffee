class Timeline
    constructor: (data, domains, bin_spacing=50, bin_width=10) ->
        @bin_spacing = bin_spacing
        @bin_width = bin_width
        @domains = domains

        @dom = null

        @timeAxis_padding = 20

        @data = data
        [first_data, ..., last_data] = data

        @first_week = new Date(first_data.key)
        @last_week  = new Date(last_data.key)        

        # Time scale
        @time = d3.time.scale()
            .domain([@first_week, @last_week])
            .range([0, @bin_spacing * @data.length])

        # Vertical scale
        @y = d3.scale.linear()
            .domain([0, d3.max(@data, (d) -> d.values)])
            .range([@domains[1][0], @domains[1][1]])

        @timeAxis = d3.svg.axis()
            .scale(@time)
            .orient("bottom")
            .ticks(d3.time.weeks)
            .tickFormat(d3.time.format("%a %d"))

    render: (svg, id='#timeline') ->
        @dom = svg.append("g")
            .attr("id", id)
            .attr("class", "timeline")

        @dom.append("g")
            .attr("class", "time axis")
            .attr("transform", "translate(0," + (@domains[1][0] - @timeAxis_padding) + ")")
            .call(@timeAxis)

        # Render bars
        @bar = @dom.selectAll(".bar")
            .data(@data)
            .enter().append("g")
            .attr("class", "bar")
            .attr("transform", (d) => "translate(" + @time(new Date(d.key)) + "," + @y(d.values) + ")")

        @bar.append("rect")
            .attr("x", - @bin_width / 2)
            .attr("width", @bin_width)
            .attr("height", (d) => @domains[1][0] - @timeAxis_padding - @y(d.values))

    selectBar: (id, duration=200) ->
        @dom.selectAll('.bar')
            .attr("class", (d, i) -> if i == id then "bar selected" else "bar")

        @dom
            .transition()
            .ease("sin")
            .duration(duration)
            .attr("transform", "translate(" + (width / 2 - @time(new Date(@data[id].key))) + ", 0)")




dimension_window = () ->
    w = window
    d = document
    e = d.documentElement
    g = d.getElementsByTagName('body')[0]
    x = w.innerWidth || e.clientWidth || g.clientWidth
    y = w.innerHeight|| e.clientHeight|| g.clientHeight

    return [x, y]


# SVG element (full-size)
[width, height] = dimension_window()
svg = d3.select("body").append("svg")
    .attr("width", width)
    .attr("height", height)


hist_height = 100
bin_width = 10
margin = left: 10, right: 10, bottom: 10, top: 10


# Load (random) data
#d3.json "data/random.json", (data) ->
#    events = data.events

d3.csv "data/big_sample.csv", (events) ->

    me = "37349f07c95879abf625e8e7ae56170c"
    events.forEach((d) ->
        d.date = new Date(d.date)
        if d.caller_id == me
            d.sender = "me"
            d.receiver = d.callee_id
        else
            d.sender = d.caller_id
            d.receiver = "me"
        d.date = new Date(d.datetime)
    )

    events = events.sort((d) -> d.date)
    nested_data = d3.nest()
        .key((d) -> new Date(d3.time.week(d.date)))
        .sortKeys((a, b) -> new Date(a).valueOf() - new Date(b).valueOf())
        .rollup((a) -> d3.sum(a, (d) -> 1))
        .entries(events)


    ## Histogram
    timeline = new Timeline nested_data, [[0, width], [height, height - 200]]
    timeline.render svg

    selected_week_id = nested_data.length // 2
    selected_week = new Date(nested_data[selected_week_id].key)
    timeline.selectBar selected_week_id


    #
    # Ego network
    #

    fill = d3.scale.category20c()

    ego = d3.nest()
        .key((d) -> if d.sender == "me" then d.receiver else d.sender)
        .entries(events)

    weekly_nest = d3.nest()
        .key((d) -> d3.time.week(d.date))


    ego.forEach((d) ->
        d.week_groups = weekly_nest.map(d.values, d3.map)
        d.radius = d.week_groups.get(selected_week)?.length
    )


    bubble = d3.layout.pack()
        .value((d) -> d.week_groups.get(selected_week)?.length)
        .sort(null)
        .padding(50)
        .radius((d) -> d * 10)
        .size([500, 500])

    bubbleNodes = bubble.nodes( children: ego )

    egoChart = svg.selectAll(".ego")
        .data(bubbleNodes)
        .enter().append("g")
        .attr("class", "ego")
        .attr("transform", (d) -> "translate(" + d.x + "," + d.y + ")")

    egoCircles = egoChart.append("circle")
     .attr("r", (d) -> d.r)
     .attr("opacity", 0.4)
     .style("fill", (d) -> d.key && fill(d.key) || "none" )

    egoTitles = egoChart.append("text")
        .attr("text-anchor", "left")
        .attr("dy", ".3em")
        .text((d) -> if (d.key && d.r > 0) then d.key.substring(0, 5))

    tick = () ->
        egoChart
            .data(bubbleNodes)
            .attr("transform", (d) -> "translate(" + d.x + "," + d.y + ")")

    force = d3.layout.force()
        .nodes(bubbleNodes)
        .size([500, 500])
        .charge((d) -> if d.radius then -Math.pow(d.radius, 1) * 50 else 0)
        .on("tick", tick)
        .start()

    d3.select('body').on("keydown", () ->
        key = d3.event.keyCode

        if key == 37 and selected_week_id > 0
            selected_week_id -= 1
        else if key == 39 and selected_week_id < nested_data.length - 1
            selected_week_id += 1

        selected_week = new Date(nested_data[selected_week_id].key)
        
        timeline.selectBar selected_week_id

        force.nodes().forEach((d) ->
            d.radius = d.week_groups?.get(selected_week)?.length
            d.r = d.radius * 10
        )

        force
            .charge((d) -> if d.radius then -Math.pow(d.radius, 1) * 50 else 0)
            .start()

        egoCircles
            .transition()
            .duration(200)
            .attr("r", (d) -> d.radius * 10)

        egoTitles
            .text((d) -> if (d.key && d.r > 0) then d.key.substring(0, 5))
    )

