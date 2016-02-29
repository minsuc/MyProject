@everywhere function myrange(q::SharedArray)
    idx = indexpids(q)
    if idx == 0
        # This worker is not assigned a piece
        return 1:0, 1:0
    end
    nchunks = length(procs(q))
    splits = [round(Int, s) for s in linspace(0,size(q,1),nchunks+1)]
    splits[idx]+1:splits[idx+1], 1:size(q,2) 
end


@everywhere function test(mValueFunctionNew::SharedArray, mPolicyFunction::SharedArray, irange::UnitRange, jrange::UnitRange, pparams::Array, vGridCapital::Array, mOutput::Array, expectedValueFunction::Array)
    aalpha = pparams[1]
    bbeta = pparams[2]
    nGridCapital = round(Int,pparams[3])
    nGridProductivity = round(Int,pparams[4])
    
   # @show (irange, jrange)
    for nProductivity in jrange
    
         gridCapitalNextPeriod = 1
    
        for nCapital in irange
            
             valueHighSoFar = -1000.0
             capitalChoice = vGridCapital[1]
   
    
            for nCapitalNextPeriod = gridCapitalNextPeriod:nGridCapital
                consumption = mOutput[nCapital,nProductivity]-vGridCapital[nCapitalNextPeriod]
                valueProvisional = (1-bbeta)*log(consumption)+bbeta*expectedValueFunction[nCapitalNextPeriod,nProductivity]
                    
                    if (valueProvisional>valueHighSoFar)
                        valueHighSoFar = valueProvisional
                        capitalChoice = vGridCapital[nCapitalNextPeriod]
                        gridCapitalNextPeriod = round(Int,nCapitalNextPeriod)
                    else
                        break
                    end
            end
            
          mValueFunctionNew[nCapital, nProductivity] = valueHighSoFar
          mPolicyFunction[nCapital, nProductivity] = capitalChoice
        
        end     
    end      
end


@everywhere test_chunk(mValueFunctionNew, mPolicyFunction, pparams, vGridCapital, mOutput, expectedValueFunction) =  test(mValueFunctionNew, mPolicyFunction, myrange(mPolicyFunction)..., pparams, vGridCapital, mOutput, expectedValueFunction)


function final_shared(mValueFunctionNew::SharedArray, mPolicyFunction::SharedArray, pparams::Array, vGridCapital::Array, mOutput::Array, expectedValueFunction::Array)
    #@sync begin
        for p in procs(mPolicyFunction)
        #@time  @async  
        @time remotecall_wait(test_chunk, p, mValueFunctionNew, mPolicyFunction, pparams, vGridCapital, mOutput, expectedValueFunction)
        end
    #end
end