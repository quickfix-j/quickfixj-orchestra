module orchesta.interfaces.qf {
  requires transitive orchesta.repository.qf ;
  requires quickfixj.core;
  
  exports io.fixprotocol.orchestra.model.quickfix;
}