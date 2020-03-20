using DataStructures: capacity

@kwdef mutable struct DelayBufferHandler <: AbstractHandler
    id = 0
    pushpopmap::Dict{Symbol, NamedTuple} = Dict{Symbol, NamedTuple}()
end

@register(DelayBufferHandler, popfirst!, [CircularBuffer{DBit}] => [DBit])
@register(DelayBufferHandler, push!, [CircularBuffer{DBit}, DBit] => [])

function (handler::DelayBufferHandler)(netlist::Netlist,
                                       inputs::Vector{Variable},
                                       outputs::Vector{Variable})
    buffname = inputs[1].name

    if length(inputs) == 1 && gettype(inputs[1]) == Symbol("CircularBuffer{DBit}")
        # record pop in map
        if haskey(handler.pushpopmap, buffname)
            handler.pushpopmap[buffname] = (push = handler.pushpopmap[buffname][:push],
                                            pop = outputs[1],
                                            delay = handler.pushpopmap[buffname][:delay],
                                            processed = false)
        else
            error("Cannot find delay buffer $buffname in handler records.")
        end
    else
        # record push in map
        if haskey(handler.pushpopmap, buffname)
            handler.pushpopmap[buffname] = (push = inputs[2],
                                            pop = handler.pushpopmap[buffname][:pop],
                                            delay = handler.pushpopmap[buffname][:delay],
                                            processed = false)
        else
            error("Cannot find delay buffer $buffname in handler records.")
        end
    end

    if haskey(handler.pushpopmap, buffname) && !any(isnothing, handler.pushpopmap[buffname]) && !handler.pushpopmap[buffname][:processed]
        outstring = """
            $stdcomment
            // BEGIN delay_buff$(handler.id)
            delay_buffer #(
                    .DELAY($(handler.pushpopmap[buffname][:delay]))
                ) delay_buff$(handler.id) (
                    .CLK(CLK),
                    .nRST(nRST),
                    .x($(handler.pushpopmap[buffname][:push])),
                    .y($(handler.pushpopmap[buffname][:pop]))
                );
            // END delay_buff$(handler.id)
            \n"""

        handler.pushpopmap[buffname] = (push = handler.pushpopmap[buffname][:push],
                                        pop = handler.pushpopmap[buffname][:pop],
                                        delay = handler.pushpopmap[buffname][:delay],
                                        processed = true)

        handler.id += 1
    else
        outstring = ""
    end

    return outstring
end

function extractrtinfo!(handler::DelayBufferHandler, innames, outname, opname, inputs, output, op)
    if op == popfirst!
        buffname = innames[1]

        if !haskey(handler.pushpopmap, buffname)
            handler.pushpopmap[buffname] = (push = nothing, pop = nothing, delay = capacity(inputs[1]), processed = false)
        end
    elseif op == push!
        buffname = innames[1]

        if !haskey(handler.pushpopmap, buffname)
            handler.pushpopmap[buffname] = (push = nothing, pop = nothing, delay = capacity(inputs[1]), processed = false)
        end
    end
end