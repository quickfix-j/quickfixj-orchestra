module orchesta.interfaces.qf {
  requires transitive orchesta.repository ;
  requires quickfixj.core;
  
  exports io.fixprotocol.orchestra.session.quickfix;
}