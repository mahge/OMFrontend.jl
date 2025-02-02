module GC

using MetaModelica
using ExportAll
#= Forward declarations for uniontypes until Julia adds support for mutual recursion =#

@UniontypeDecl ProfStats

#= /*
* This file is part of OpenModelica.
*
* Copyright (c) 1998-2014, Open Source Modelica Consortium (OSMC),
* c/o Linköpings universitet, Department of Computer and Information Science,
* SE-58183 Linköping, Sweden.
*
* All rights reserved.
*
* THIS PROGRAM IS PROVIDED UNDER THE TERMS OF GPL VERSION 3 LICENSE OR
* THIS OSMC PUBLIC LICENSE (OSMC-PL) VERSION 1.2.
* ANY USE, REPRODUCTION OR DISTRIBUTION OF THIS PROGRAM CONSTITUTES
* RECIPIENT'S ACCEPTANCE OF THE OSMC PUBLIC LICENSE OR THE GPL VERSION 3,
* ACCORDING TO RECIPIENTS CHOICE.
*
* The OpenModelica software and the Open Source Modelica
* Consortium (OSMC) Public License (OSMC-PL) are obtained
* from OSMC, either from the above address,
* from the URLs: http:www.ida.liu.se/projects/OpenModelica or
* http:www.openmodelica.org, and in the OpenModelica distribution.
* GNU version 3 is obtained from: http:www.gnu.org/copyleft/gpl.html.
*
* This program is distributed WITHOUT ANY WARRANTY; without
* even the implied warranty of  MERCHANTABILITY or FITNESS
* FOR A PARTICULAR PURPOSE, EXCEPT AS EXPRESSLY SET FORTH
* IN THE BY RECIPIENT SELECTED SUBSIDIARY LICENSE CONDITIONS OF OSMC-PL.
*
* See the full OSMC Public License conditions for more details.
*
*/ =#

function gcollect()
  return @error "TODO: Defined in the runtime"
end

function gcollectAndUnmap()
  return @error "TODO: Defined in the runtime"
end

function enable()
  return @error "TODO: Defined in the runtime"
end

function disable()
  return @error "TODO: Defined in the runtime"
end

function free(data::T) where {T}
  return @error "TODO: Defined in the runtime"
end

function expandHeap(sz::AbstractFloat)::Bool #= To avoid the 32-bit signed limit on sizes =#
  local success::Bool

  @error "TODO: Defined in the runtime"
  return success
end

function setFreeSpaceDivisor(divisor::Integer = 3)
  return @error "TODO: Defined in the runtime"
end

function getForceUnmapOnGcollect()::Bool
  local res::Bool

  @error "TODO: Defined in the runtime"
  return res
end

function setForceUnmapOnGcollect(forceUnmap::Bool)
  return @error "TODO: Defined in the runtime"
end

function setMaxHeapSize(sz::AbstractFloat) #= To avoid the 32-bit signed limit on sizes =#
  return @error "TODO: Defined in the runtime"
end

#= TODO: Support regular records in the bootstrapped compiler to avoid allocation to return the stats in the GC... =#
@Uniontype ProfStats begin
  @Record PROFSTATS begin

    heapsize_full::Integer
    free_bytes_full::Integer
    unmapped_bytes::Integer
    bytes_allocd_since_gc::Integer
    allocd_bytes_before_gc::Integer
    non_gc_bytes::Integer
    gc_no::Integer
    markers_m1::Integer
    bytes_reclaimed_since_gc::Integer
    reclaimed_bytes_before_gc::Integer
  end
end

function profStatsStr(
  stats::ProfStats,
  head::String = "GC Profiling Stats: ",
  delimiter::String = "\\n  ",
)::String
  local str::String

  @assign str = begin
    @match stats begin
      PROFSTATS(__) => begin
        head +
        delimiter +
        "heapsize_full: " +
        intString(stats.heapsize_full) +
        delimiter +
        "free_bytes_full: " +
        intString(stats.free_bytes_full) +
        delimiter +
        "unmapped_bytes: " +
        intString(stats.unmapped_bytes) +
        delimiter +
        "bytes_allocd_since_gc: " +
        intString(stats.bytes_allocd_since_gc) +
        delimiter +
        "allocd_bytes_before_gc: " +
        intString(stats.allocd_bytes_before_gc) +
        delimiter +
        "total_allocd_bytes: " +
        intString(stats.bytes_allocd_since_gc + stats.allocd_bytes_before_gc) +
        delimiter +
        "non_gc_bytes: " +
        intString(stats.non_gc_bytes) +
        delimiter +
        "gc_no: " +
        intString(stats.gc_no) +
        delimiter +
        "markers_m1: " +
        intString(stats.markers_m1) +
        delimiter +
        "bytes_reclaimed_since_gc: " +
        intString(stats.bytes_reclaimed_since_gc) +
        delimiter +
        "reclaimed_bytes_before_gc: " +
        intString(stats.reclaimed_bytes_before_gc)
      end
    end
  end
  return str
end

function getProfStats()::ProfStats
  local stats::ProfStats

  local heapsize_full::Integer
  local free_bytes_full::Integer
  local unmapped_bytes::Integer
  local bytes_allocd_since_gc::Integer
  local allocd_bytes_before_gc::Integer
  local non_gc_bytes::Integer
  local gc_no::Integer
  local markers_m1::Integer
  local bytes_reclaimed_since_gc::Integer
  local reclaimed_bytes_before_gc::Integer

  """ #= Inner, dummy function to preserve the full integer sizes =#"""
  function GC_get_prof_stats_modelica()::Tuple{
    Integer,
    Integer,
    Integer,
    Integer,
    Integer,
    Integer,
    Integer,
    Integer,
    Integer,
    Integer,
  }
    local stats::Tuple{
      Integer,
      Integer,
      Integer,
      Integer,
      Integer,
      Integer,
      Integer,
      Integer,
      Integer,
      Integer,
    }

    @error "TODO: Defined in the runtime"
    return stats
  end

  @assign (
    heapsize_full,
    free_bytes_full,
    unmapped_bytes,
    bytes_allocd_since_gc,
    allocd_bytes_before_gc,
    non_gc_bytes,
    gc_no,
    markers_m1,
    bytes_reclaimed_since_gc,
    reclaimed_bytes_before_gc,
  ) = GC_get_prof_stats_modelica()
  @assign stats = PROFSTATS(
    heapsize_full,
    free_bytes_full,
    unmapped_bytes,
    bytes_allocd_since_gc,
    allocd_bytes_before_gc,
    non_gc_bytes,
    gc_no,
    markers_m1,
    bytes_reclaimed_since_gc,
    reclaimed_bytes_before_gc,
  )
  return stats
end

@exportAll()
end
