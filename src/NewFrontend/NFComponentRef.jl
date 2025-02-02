FuncT = Function
@UniontypeDecl NFComponentReff

ComponentRef = NFComponentRef
Origin = (() -> begin #= Enumeration =#
  CREF = 1  #= From an Absyn cref. =#
  SCOPE = 2  #= From prefixing the cref with its scope. =#
  ITERATOR = 3  #= From an iterator. =#
  () -> (CREF; SCOPE; ITERATOR)  #= From an iterator. =#
end)()
const OriginType = Int


@Uniontype NFComponentRef begin
  @Record COMPONENT_REF_STRING begin
    name::String
    restCref::ComponentRef
  end
  @Record COMPONENT_REF_WILD begin
  end
  @Record COMPONENT_REF_EMPTY begin
  end
  @Record COMPONENT_REF_CREF begin
    node::InstNode
    subscripts::List{Subscript}
    ty::NFType #= The type of the node, without taking subscripts into account. =#
    origin::OriginType
    restCref::ComponentRef
  end
end

function isComplexArray2(cref::ComponentRef)::Bool
  local complexArray::Bool
  @assign complexArray = begin
    @match cref begin
      COMPONENT_REF_CREF(
        ty = TYPE_ARRAY(__),
      ) where {(isArray(Type.subscript(cref.ty, cref.subscripts)))} => begin
        true
      end

      COMPONENT_REF_CREF(__) => begin
        isComplexArray2(cref.restCref)
      end

      _ => begin
        false
      end
    end
  end
  return complexArray
end

function isComplexArray(cref::ComponentRef)::Bool
  local complexArray::Bool

  @assign complexArray = begin
    @match cref begin
      COMPONENT_REF_CREF(__) => begin
        isComplexArray2(cref.restCref)
      end

      _ => begin
        false
      end
    end
  end
  return complexArray
end

function depth(cref::ComponentRef)::Int
  local d::Int = 0

  @assign d = begin
    @match cref begin
      COMPONENT_REF_CREF(restCref = COMPONENT_REF_EMPTY(__)) => begin
        d + 1
      end

      COMPONENT_REF_CREF(__) => begin
        @assign d = 1 + depth(cref.restCref)
        d
      end

      COMPONENT_REF_WILD(__) => begin
        0
      end

      _ => begin  #= COMPONENT_REF_EMPTY_COMPONENT_REF_CREF =#
        0
      end
    end
  end
  return d
end

function toListReverse(
  cref::ComponentRef,
  accum::List{<:ComponentRef} = nil,
)::List{ComponentRef}
  local crefs::List{ComponentRef}
  @assign crefs = begin
    @match cref begin
      COMPONENT_REF_CREF(origin = Origin.CREF) => begin
        toListReverse(cref.restCref, _cons(cref, accum))
      end
      _ => begin
        accum
      end
    end
  end
  return crefs
end

function isFromCref(cref::ComponentRef)::Bool
  local fromCref::Bool

  @assign fromCref = begin
    @match cref begin
      COMPONENT_REF_CREF(origin = Origin.CREF) => begin
        true
      end

      COMPONENT_REF_WILD(__) => begin
        true
      end

      _ => begin
        false
      end
    end
  end
  return fromCref
end

function isDeleted(cref::ComponentRef)::Bool
  local isDeletedBool::Bool

  @assign isDeletedBool = begin
    local node::InstNode
    @match cref begin
      COMPONENT_REF_CREF(node = node, origin = Origin.CREF) => begin
        isComponent(node) && isDeleted(component(node))
      end

      _ => begin
        false
      end
    end
  end
  return isDeletedBool
end

function evaluateSubscripts(cref::ComponentRef)::ComponentRef

  @assign cref = begin
    local subs::List{Subscript}
    @match cref begin
      COMPONENT_REF_CREF(subscripts = nil(), origin = Origin.CREF) => begin
        @assign cref.restCref = evaluateSubscripts(cref.restCref)
        cref
      end

      COMPONENT_REF_CREF(origin = Origin.CREF) => begin
        @assign subs = list(eval(s) for s in cref.subscripts)
        COMPONENT_REF_CREF(cref.node, subs, cref.ty, cref.origin, evaluateSubscripts(cref.restCref))
      end

      _ => begin
        cref
      end
    end
  end
  return cref
end

function simplifySubscripts(cref::ComponentRef)::ComponentRef
  @assign cref = begin
    local subs::List{Subscript}
    @match cref begin
      COMPONENT_REF_CREF(subscripts = nil(), origin = Origin.CREF) => begin
        @assign cref.restCref = simplifySubscripts(cref.restCref)
        cref
      end
      COMPONENT_REF_CREF(origin = Origin.CREF) => begin
        @assign subs = list(simplifySubscript(s) for s in cref.subscripts)
        COMPONENT_REF_CREF(cref.node, subs, cref.ty, cref.origin, simplifySubscripts(cref.restCref))
      end
      _ => begin
        cref
      end
    end
  end
  return cref
end

""" #= Strips all subscripts from a cref. =#"""
function stripSubscriptsAll(cref::ComponentRef)::ComponentRef
  local strippedCref::ComponentRef
  @assign strippedCref = begin
    @match cref begin
      COMPONENT_REF_CREF(__) => begin
        COMPONENT_REF_CREF(cref.node, nil, cref.ty, cref.origin, stripSubscriptsAll(cref.restCref))
      end

      _ => begin
        cref
      end
    end
  end
  return strippedCref
end

""" #= Strips the subscripts from the last name in a cref, e.g. a[2].b[3] => a[2].b =#"""
function stripSubscripts(cref::ComponentRef)::Tuple{ComponentRef, List{Subscript}}
  local subs::List{Subscript}
  local strippedCref::ComponentRef

  @assign (strippedCref, subs) = begin
    @match cref begin
      COMPONENT_REF_CREF(__) => begin
        (COMPONENT_REF_CREF(cref.node, nil, cref.ty, cref.origin, cref.restCref), cref.subscripts)
      end

      _ => begin
        (cref, nil)
      end
    end
  end
  return (strippedCref, subs)
end

function isPackageConstant2(cref::ComponentRef)::Bool
  local isPkgConst::Bool

  @assign isPkgConst = begin
    @match cref begin
      COMPONENT_REF_CREF(node = CLASS_NODE(__)) => begin
        isUserdefinedClass(cref.node)
      end

      COMPONENT_REF_CREF(origin = Origin.CREF) => begin
        isPackageConstant2(cref.restCref)
      end

      _ => begin
        false
      end
    end
  end
  return isPkgConst
end

function isPackageConstant(cref::ComponentRef)::Bool
  local isPkgConst::Bool

  #=  TODO: This should really be CONSTANT and not PARAMETER, but that breaks
  =#
  #=        some models since we get some redeclared parameters that look like
  =#
  #=        package constants due to redeclare issues, and which need to e.g.
  =#
  #=        be collected by Package.collectConstants.
  =#
  @assign isPkgConst =
    nodeVariability(cref) <= Variability.PARAMETER && isPackageConstant2(cref)
  return isPkgConst
end

function scalarize(cref::ComponentRef)::List{ComponentRef}
  local crefs::List{ComponentRef}

  @assign crefs = begin
    local dims::List{Dimension}
    local subs::List{List{Subscript}}
    @match cref begin
      COMPONENT_REF_CREF(ty = TYPE_ARRAY(__)) => begin
        @assign dims = arrayDims(cref.ty)
        @assign subs = scalarizeList(cref.subscripts, dims)
        @assign subs = ListUtil.combination(subs)
        list(setSubscripts(s, cref) for s in subs)
      end

      _ => begin
        list(cref)
      end
    end
  end
  return crefs
end

function fromNodeList(nodes::List{<:InstNode})::ComponentRef
  local cref::ComponentRef = COMPONENT_REF_EMPTY()

  for n in nodes
    @assign cref = COMPONENT_REF_CREF(n, nil, getType(n), Origin.SCOPE, cref)
  end
  return cref
end

function toPath_impl(cref::ComponentRef, accumPath::Absyn.Path)::Absyn.Path
  local path::Absyn.Path

  @assign path = begin
    @match cref begin
      COMPONENT_REF_CREF(__) => begin
        toPath_impl(cref.restCref, Absyn.QUALIFIED(name(cref.node), accumPath))
      end

      _ => begin
        accumPath
      end
    end
  end
  return path
end

function toPath(cref::ComponentRef)::Absyn.Path
  local path::Absyn.Path

  @assign path = begin
    @match cref begin
      COMPONENT_REF_CREF(__) => begin
        toPath_impl(cref.restCref, Absyn.IDENT(name(cref.node)))
      end
    end
  end
  return path
end

function hash(cref::ComponentRef, mod::Int)::Int
  local hash::Int = stringHashDjb2Mod(toString(cref), mod)
  return hash
end

function listToString(crs::List{<:ComponentRef})::String
  local str::String

  @assign str = "{" + stringDelimitList(ListUtil.map(crs, toString), ",") + "}"
  return str
end

function toFlatString_impl(cref::ComponentRef, strl::List{<:String})::List{String}

  @assign strl = begin
    local str::String
    @match cref begin
      COMPONENT_REF_CREF(__) => begin
        @assign str =
          name(cref.node) +
          toFlatStringList(cref.subscripts)
        if Type.isRecord(cref.ty) && !listEmpty(strl)
          @assign strl = _cons("'" + listHead(strl), listRest(strl))
          @assign str = str + "'"
        end
        toFlatString_impl(cref.restCref, _cons(str, strl))
      end

      COMPONENT_REF_WILD(__) => begin
        _cons("_", strl)
      end

      COMPONENT_REF_STRING(__) => begin
        toFlatString_impl(cref.restCref, _cons(cref.name, strl))
      end

      _ => begin
        strl
      end
    end
  end
  return strl
end

function toFlatString(cref::ComponentRef)::String
  local str::String

  local cr::ComponentRef
  local subs::List{Subscript}
  local strl::List{String} = nil

  @assign (cr, subs) = stripSubscripts(cref)
  @assign strl = toFlatString_impl(cr, strl)
  @assign str = stringAppendList(list(
    "'",
    stringDelimitList(strl, "."),
    "'",
    toFlatStringList(subs),
  ))
  return str
end

function toString_impl(cref::ComponentRef, strl::List{<:String})::List{String}

  @assign strl = begin
    local str::String
    @match cref begin
      COMPONENT_REF_CREF(__) => begin
        @assign str =
          name(cref.node) + toStringList(cref.subscripts)
        toString_impl(cref.restCref, _cons(str, strl))
      end

      COMPONENT_REF_WILD(__) => begin
        _cons("_", strl)
      end

      COMPONENT_REF_STRING(__) => begin
        toString_impl(cref.restCref, _cons(cref.name, strl))
      end

      _ => begin
        strl
      end
    end
  end
  return strl
end

function toString(cref::ComponentRef)::String
  local str::String

  @assign str = stringDelimitList(toString_impl(cref, nil), ".")
  return str
end

function toDAE_impl(
  cref::ComponentRef,
  accumCref::DAE.ComponentRef
)::DAE.ComponentRef
  local dcref::DAE.ComponentRef

  @assign dcref = begin
    local ty::M_Type
    local dty::DAE.Type
    @match cref begin
      COMPONENT_REF_EMPTY(__) => begin
        accumCref
      end
      COMPONENT_REF_CREF(__) => begin
        @assign ty = if isUnknown(cref.ty)
          getType(cref.node)
        else
          cref.ty
        end
        @assign dty = toDAE(ty, makeTypeVars = false)
        @assign dcref = DAE.CREF_QUAL(
          name(cref.node),
          dty,
          list(toDAE(s) for s in cref.subscripts),
          accumCref,
        )
        toDAE_impl(cref.restCref, dcref)
      end
    end
  end
  return dcref
end

function toDAE(cref::ComponentRef)::DAE.ComponentRef
  local dcref::DAE.ComponentRef
  @assign dcref = begin
    @match cref begin
      COMPONENT_REF_CREF(__) => begin
        @assign dcref = DAE.CREF_IDENT(
          name(cref.node),
          toDAE(cref.ty),
          list(toDAE(s) for s in cref.subscripts),
        )
        toDAE_impl(cref.restCref, dcref)
      end

      COMPONENT_REF_WILD(__) => begin
        DAE.WILD()
      end
    end
  end
  return dcref
end

function isPrefix(cref1::ComponentRef, cref2::ComponentRef)::Bool
  local isPrefix::Bool

  if referenceEq(cref1, cref2)
    @assign isPrefix = true
    return isPrefix
  end
  @assign isPrefix = begin
    @match (cref1, cref2) begin
      (COMPONENT_REF_CREF(__), COMPONENT_REF_CREF(__)) => begin
        if name(cref1.node) == name(cref2.node)
          isEqual(cref1.restCref, cref2.restCref)
        else
          isEqual(cref1, cref2.restCref)
        end
      end

      _ => begin
        false
      end
    end
  end
  return isPrefix
end

function isGreater(cref1::ComponentRef, cref2::ComponentRef)::Bool
  local isGreater::Bool = compare(cref1, cref2) > 0
  return isGreater
end

function isLess(cref1::ComponentRef, cref2::ComponentRef)::Bool
  local isLess::Bool = compare(cref1, cref2) < 0
  return isLess
end

function isEqual(cref1::ComponentRef, cref2::ComponentRef)::Bool
  local isEqualB::Bool = false
  if referenceEq(cref1, cref2)
    return true
  end
  isEqualB = begin
    @match (cref1, cref2) begin
      (COMPONENT_REF_CREF(__), COMPONENT_REF_CREF(__)) => begin
        name(cref1.node) == name(cref2.node) &&
        isEqualList(cref1.subscripts, cref2.subscripts) &&
        isEqual(cref1.restCref, cref2.restCref)
      end

      (COMPONENT_REF_EMPTY(__), COMPONENT_REF_EMPTY(__)) => begin
        true
      end

      (COMPONENT_REF_WILD(__), COMPONENT_REF_WILD(__)) => begin
        true
      end
      _ => begin
        false
      end
    end
  end
  return isEqualB
end

function compare(cref1::ComponentRef, cref2::ComponentRef)::Int
  local comp::Int

  @assign comp = begin
    @match (cref1, cref2) begin
      (COMPONENT_REF_CREF(__), COMPONENT_REF_CREF(__)) => begin
        comp =
          stringCompare(name(cref1.node), name(cref2.node))
        if comp != 0
          return comp #? - John
        end
         comp =
          compareList(cref1.subscripts, cref2.subscripts)
        if comp != 0
          return comp #? - John
        end
        compare(cref1.restCref, cref2.restCref)
      end

      (COMPONENT_REF_EMPTY(__), COMPONENT_REF_EMPTY(__)) => begin
        0
      end

      (_, COMPONENT_REF_EMPTY(__)) => begin
        1
      end

      (COMPONENT_REF_EMPTY(__), _) => begin
        -1
      end
    end
  end
  return comp
end

function foldSubscripts(cref::ComponentRef, func::FuncT, arg::ArgT) where {ArgT}

  @assign arg = begin
    @match cref begin
      COMPONENT_REF_CREF(origin = Origin.CREF) => begin
        for sub in cref.subscripts
          @assign arg = func(sub, arg)
        end
        foldSubscripts(cref.restCref, func, arg)
      end

      _ => begin
        arg
      end
    end
  end
  return arg
end

""" #= Copies subscripts from one cref to another, overwriting any subscripts on
     the destination cref. =#"""
function transferSubscripts(srcCref::ComponentRef, dstCref::ComponentRef)::ComponentRef
  local cref::ComponentRef

  @assign cref = begin
    @match (srcCref, dstCref) begin
      (COMPONENT_REF_EMPTY(__), _) => begin
        dstCref
      end

      (_, COMPONENT_REF_EMPTY(__)) => begin
        dstCref
      end

      (_, COMPONENT_REF_CREF(origin = Origin.ITERATOR)) => begin
        dstCref
      end

      (COMPONENT_REF_CREF(__), COMPONENT_REF_CREF(origin = Origin.CREF)) => begin
        @assign dstCref.restCref = transferSubscripts(srcCref, dstCref.restCref)
        dstCref
      end

      (COMPONENT_REF_CREF(__), COMPONENT_REF_CREF(__)) where {(refEqual(srcCref.node, dstCref.node))} =>
        begin
          @assign cref = transferSubscripts(srcCref.restCref, dstCref.restCref)
          COMPONENT_REF_CREF(dstCref.node, srcCref.subscripts, dstCref.ty, dstCref.origin, cref)
        end

      (COMPONENT_REF_CREF(__), COMPONENT_REF_CREF(__)) => begin
        transferSubscripts(srcCref.restCref, dstCref)
      end

      _ => begin
        Error.assertion(false, getInstanceName() + " failed", sourceInfo())
        fail()
      end
    end
  end
  return cref
end

""" #= Returns the subscripts of the N first parts of a cref in reverse order. =#"""
function subscriptsN(cref::ComponentRef, n::Int)::List{List{Subscript}}
  local subscripts::List{List{Subscript}} = nil

  local subs::List{Subscript}
  local rest::ComponentRef = cref

  for i = 1:n
    if isEmpty(rest)
      break
    end
    @match COMPONENT_REF_CREF(subscripts = subs, restCref = rest) = rest
    @assign subscripts = _cons(subs, subscripts)
  end
  return subscripts
end

""" #= Returns all subscripts of a cref as a flat list in the correct order.
     Ex: a[1, 2].b[4].c[6, 3] => {1, 2, 4, 6, 3} =#"""
function subscriptsAllFlat(cref::ComponentRef)::List{Subscript}
  local subscripts::List{Subscript} = ListUtil.flattenReverse(subscriptsAll(cref))
  return subscripts
end

""" #= Returns all subscripts of a cref in reverse order.
     Ex: a[1, 2].b[4].c[6, 3] => {{6,3}, {4}, {1,2}} =#"""
function subscriptsAll(
  cref::ComponentRef,
  accumSubs::List{<:List{<:Subscript}} = nil,
)::List{List{Subscript}}
  local subscripts::List{List{Subscript}}

  @assign subscripts = begin
    @match cref begin
      COMPONENT_REF_CREF(__) => begin
        subscriptsAll(cref.restCref, _cons(cref.subscripts, accumSubs))
      end

      _ => begin
        accumSubs
      end
    end
  end
  return subscripts
end

""" #= Sets the subscripts of each part of a cref to the corresponding list of subscripts. =#"""
function setSubscriptsList(
  subscripts::List{<:List{<:Subscript}},
  cref::ComponentRef,
)::ComponentRef

  @assign cref = begin
    local subs::List{Subscript}
    local rest_subs::List{List{Subscript}}
    local rest_cref::ComponentRef
    @match (subscripts, cref) begin
      (subs <| rest_subs, COMPONENT_REF_CREF(__)) => begin
        @assign rest_cref = setSubscriptsList(rest_subs, cref.restCref)
        COMPONENT_REF_CREF(cref.node, subs, cref.ty, cref.origin, rest_cref)
      end

      (nil(), _) => begin
        cref
      end
    end
  end
  return cref
end

""" #= Sets the subscripts of the first part of a cref. =#"""
function setSubscripts(subscripts::List{<:Subscript}, cref::ComponentRef)::ComponentRef

  @assign () = begin
    @match cref begin
      COMPONENT_REF_CREF(__) => begin
        @assign cref.subscripts = subscripts
        ()
      end
    end
  end
  return cref
end

function getSubscripts(cref::ComponentRef)::List{Subscript}
  local subscripts::List{Subscript}

  @assign subscripts = begin
    @match cref begin
      COMPONENT_REF_CREF(__) => begin
        cref.subscripts
      end

      _ => begin
        nil
      end
    end
  end
  return subscripts
end

function hasSubscripts(cref::ComponentRef)::Bool
  local hs::Bool
  @assign hs = begin
    @match cref begin
      COMPONENT_REF_CREF(__) => begin
        !listEmpty(cref.subscripts) || hasSubscripts(cref.restCref)
      end

      _ => begin
        false
      end
    end
  end
  return hs
end

function applySubscripts2(
  subscripts::List{<:Subscript},
  cref::ComponentRef,
)::Tuple{List{Subscript}, ComponentRef}

  @assign (subscripts, cref) = begin
    local rest_cref::ComponentRef
    local cref_subs::List{Subscript}
    @match cref begin
      COMPONENT_REF_CREF(subscripts = cref_subs) => begin
        @assign (subscripts, rest_cref) = applySubscripts2(subscripts, cref.restCref)
        if !listEmpty(subscripts)
          @assign (cref_subs, subscripts) = mergeList(
            subscripts,
            cref_subs,
            Type.dimensionCount(cref.ty),
          )
        end
        (subscripts, COMPONENT_REF_CREF(cref.node, cref_subs, cref.ty, cref.origin, rest_cref))
      end

      _ => begin
        (subscripts, cref)
      end
    end
  end
  return (subscripts, cref)
end

function applySubscripts(subscripts::List{<:Subscript}, cref::ComponentRef)::ComponentRef

  @match (nil, cref) = applySubscripts2(subscripts, cref)
  return cref
end

function addSubscript(subscript::Subscript, cref::ComponentRef)::ComponentRef

  @assign () = begin
    @match cref begin
      COMPONENT_REF_CREF(__) => begin
        @assign cref.subscripts = listAppend(cref.subscripts, list(subscript))
        ()
      end
    end
  end
  return cref
end

""" #= Returns the variability of the cref, with the variability of the subscripts
     taken into account. =#"""
function variability(cref::ComponentRef)::VariabilityType
  local var::VariabilityType =
    variabilityMax(nodeVariability(cref), subscriptsVariability(cref))
  return var
end

function subscriptsVariability(
  cref::ComponentRef,
  var::VariabilityType = Variability.CONSTANT,
)::VariabilityType

  @assign () = begin
    @match cref begin
      COMPONENT_REF_CREF(origin = Origin.CREF) => begin
        for sub in cref.subscripts
          @assign var =
            variabilityMax(var, variability(sub))
        end
        ()
      end

      _ => begin
        ()
      end
    end
  end
  return var
end

""" #= Returns the variability of the component node the cref refers to. =#"""
function nodeVariability(cref::ComponentRef)::VariabilityType
  local var::VariabilityType
  @assign var = begin
    @match cref begin
      COMPONENT_REF_CREF(node = COMPONENT_NODE(__)) => begin
        variability(component(cref.node))
      end
      _ => begin
        Variability.CONTINUOUS
      end
    end
  end
  return var
end

function getSubscriptedType2(restCref::ComponentRef, accumTy::NFType)::NFType
  local ty::NFType
  @assign ty = begin
    @match restCref begin
      COMPONENT_REF_CREF(origin = Origin.CREF) => begin
        @assign ty = liftArrayLeftList(
          accumTy,
          arrayDims(subscript(restCref.ty, restCref.subscripts)),
        )
        getSubscriptedType2(restCref.restCref, ty)
      end
      _ => begin
        accumTy
      end
    end
  end
  return ty
end

""" #= Returns the type of a cref, with the subscripts taken into account. =#"""
function getSubscriptedType(cref::ComponentRef)::NFType
  local ty::NFType
  @assign ty = begin
    @match cref begin
      COMPONENT_REF_CREF(__) => begin
        getSubscriptedType2(cref.restCref, subscript(cref.ty, cref.subscripts))
      end
      _ => begin
        TYPE_UNKNOWN()
      end
    end
  end
  return ty
end

""" #= Returns the type of the component the given cref refers to, without taking
     subscripts into account. =#"""
function getComponentType(cref::ComponentRef)::M_Type
  local ty::M_Type

  @assign ty = begin
    @match cref begin
      COMPONENT_REF_CREF(__) => begin
        cref.ty
      end

      _ => begin
        TYPE_UNKNOWN()
      end
    end
  end
  return ty
end

function append(cref::ComponentRef, restCref::ComponentRef)::ComponentRef

  @assign cref = begin
    @match cref begin
      COMPONENT_REF_CREF(__) => begin
        @assign cref.restCref = append(cref.restCref, restCref)
        cref
      end

      COMPONENT_REF_EMPTY(__) => begin
        restCref
      end
    end
  end
  return cref
end

function firstNonScope(cref::ComponentRef)::ComponentRef
  local first::ComponentRef

  local rest_cr::ComponentRef = rest(cref)

  @assign first = begin
    @match rest_cr begin
      COMPONENT_REF_CREF(origin = Origin.SCOPE) => begin
        cref
      end

      COMPONENT_REF_EMPTY(__) => begin
        cref
      end

      _ => begin
        firstNonScope(rest_cr)
      end
    end
  end
  return first
end

function rest(cref::ComponentRef)::ComponentRef
  local restCref::ComponentRef

  @match COMPONENT_REF_CREF(restCref = restCref) = cref
  return restCref
end

function firstName(cref::ComponentRef)::String
  local nameVar::String
  @assign nameVar = begin
    @match cref begin
      COMPONENT_REF_CREF(__) => begin
        name(cref.node)
      end
      _ => begin
        ""
      end
    end
  end
  return nameVar
end

function updateNodeType(cref::ComponentRef)::ComponentRef

  @assign () = begin
    @match cref begin
      COMPONENT_REF_CREF(__) => begin
        @assign cref.ty = getType(cref.node)
        ()
      end

      _ => begin
        ()
      end
    end
  end
  return cref
end

function nodeType(cref::ComponentRef)::M_Type
  local ty::M_Type

  @match COMPONENT_REF_CREF(ty = ty) = cref
  return ty
end

function containsNode(cref::ComponentRef, node::InstNode)::Bool
  local res::Bool

  @assign res = begin
    @match cref begin
      COMPONENT_REF_CREF(__) => begin
        refEqual(cref.node, node) || containsNode(cref.restCref, node)
      end

      _ => begin
        false
      end
    end
  end
  return res
end

function node(cref::ComponentRef)::InstNode
  local node::InstNode

  @match COMPONENT_REF_CREF(node = node) = cref
  return node
end

function isIterator(cref::ComponentRef)::Bool
  local isIterator::Bool

  @assign isIterator = begin
    @match cref begin
      COMPONENT_REF_CREF(origin = Origin.ITERATOR) => begin
        true
      end

      _ => begin
        false
      end
    end
  end
  return isIterator
end

function isSimple(cref::ComponentRef)::Bool
  local isSimple::Bool

  @assign isSimple = begin
    @match cref begin
      COMPONENT_REF_CREF(restCref = COMPONENT_REF_EMPTY(__)) => begin
        true
      end

      _ => begin
        false
      end
    end
  end
  return isSimple
end

function isEmpty(cref::ComponentRef)::Bool
  local isEmpty::Bool

  @assign isEmpty = begin
    @match cref begin
      COMPONENT_REF_EMPTY(__) => begin
        true
      end

      _ => begin
        false
      end
    end
  end
  return isEmpty
end

function makeIterator(node::InstNode, ty::NFType)::ComponentRef
  local cref::ComponentRef = COMPONENT_REF_CREF(node, nil, ty, Origin.ITERATOR, COMPONENT_REF_EMPTY())
  return cref
end

function fromBuiltin(node::InstNode, ty::M_Type)::ComponentRef
  local cref::ComponentRef = COMPONENT_REF_CREF(node, nil, ty, Origin.SCOPE, COMPONENT_REF_EMPTY())
  return cref
end

function fromAbsynCref(
  acref::Absyn.ComponentRef,
  restCref::ComponentRef = COMPONENT_REF_EMPTY(),
)::ComponentRef
  local cref::ComponentRef
  @assign cref = begin
    @match acref begin
      Absyn.CREF_IDENT(__) => begin
        fromAbsyn(NAME_NODE(acref.name), acref.subscripts, restCref)
      end
      Absyn.CREF_QUAL(__) => begin
        fromAbsynCref(
          acref.componentRef,
          fromAbsyn(NAME_NODE(acref.name), acref.subscripts, restCref),
        )
      end
      Absyn.CREF_FULLYQUALIFIED(__) => begin
        fromAbsynCref(acref.componentRef)
      end
      Absyn.WILD(__) => begin
        COMPONENT_REF_WILD()
      end
      Absyn.ALLWILD(__) => begin
        COMPONENT_REF_WILD()
      end
    end
  end
  return cref
end

function fromAbsyn(
  node::InstNode,
  subs::List{<:Absyn.Subscript},
  restCref::ComponentRef = COMPONENT_REF_EMPTY(),
)::ComponentRef
  local cref::ComponentRef
  local sl::List{Subscript}
  @assign sl = list(SUBSCRIPT_RAW_SUBSCRIPT(s) for s in subs)
  @assign cref = COMPONENT_REF_CREF(node, sl, TYPE_UNKNOWN(), Origin.CREF, restCref)
  return cref
end

function prefixScope(
  node::InstNode,
  ty::NFType,
  subs::List{<:Subscript},
  restCref::ComponentRef,
)::ComponentRef
  local cref::ComponentRef = COMPONENT_REF_CREF(node, subs, ty, Origin.SCOPE, restCref)
  return cref
end

function prefixCref(
  node::InstNode,
  ty::M_Type,
  subs::List{<:Subscript},
  restCref::ComponentRef,
)::ComponentRef
  local cref::ComponentRef = COMPONENT_REF_CREF(node, subs, ty, Origin.CREF, restCref)
  return cref
end

function fromNode(
  node::InstNode,
  ty::NFType,
  subs::List{<:Subscript} = nil,
  origin::OriginType = Origin.CREF,
)::ComponentRef
  local cref::ComponentRef = COMPONENT_REF_CREF(node, subs, ty, origin, COMPONENT_REF_EMPTY())
  return cref
end
